package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"os"
	"os/signal"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/google/uuid"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"order-processing-system/internal/models"
	"order-processing-system/internal/queue"
)

type Worker struct {
	db *gorm.DB
}

func main() {
	rand.Seed(time.Now().UnixNano())

	log.Println("========================================")
	log.Println("Payment Worker - HIGH THROUGHPUT MODE")
	log.Println("========================================")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "postgres")
	dbPass := getEnv("DB_PASSWORD", "postgres")
	dbName := getEnv("DB_NAME", "orders")

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
		dbHost, dbPort, dbUser, dbPass, dbName)

	var db *gorm.DB
	var err error

	for i := 0; i < 10; i++ {
		db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
		if err == nil {
			break
		}
		log.Printf("Failed to connect to database (attempt %d/10): %v", i+1, err)
		time.Sleep(2 * time.Second)
	}

	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	sqlDB, _ := db.DB()
	sqlDB.SetMaxOpenConns(25)
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetConnMaxLifetime(time.Hour)

	log.Println("✓ Database connected with connection pool (max 25 conns)")

	worker := &Worker{db: db}

	rabbitURL := getEnv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/")
	queueName := getEnv("QUEUE_NAME", "orders")
	dlqName := queueName + "_dlq"

	prefetchStr := getEnv("PREFETCH_COUNT", "10")
	prefetch, _ := strconv.Atoi(prefetchStr)

	rmq, err := queue.NewRabbitMQWithPrefetch(rabbitURL, queueName, dlqName, prefetch)
	if err != nil {
		log.Fatalf("Failed to connect to RabbitMQ: %v", err)
	}
	defer rmq.Close()

	log.Println("✓ RabbitMQ configured for HIGH THROUGHPUT:")
	log.Printf("  - Prefetch count: %d messages", prefetch)
	log.Printf("  - Concurrent processing: %d goroutines", prefetch)
	log.Println("  - Dead-letter queue:", dlqName)
	log.Println("  - Max retries: 3 with exponential backoff")
	log.Println("  - Graceful shutdown enabled")
	log.Println("========================================")

	var wg sync.WaitGroup

	go func() {
		if err := rmq.ConsumeWithContext(ctx, &wg, worker.processPayment); err != nil {
			log.Printf("Consumer error: %v", err)
		}
	}()

	log.Println("Payment Worker started in HIGH THROUGHPUT mode")
	log.Printf("Processing up to %d messages concurrently", prefetch)
	log.Println("Press Ctrl+C for graceful shutdown")

	<-sigChan
	log.Println("========================================")
	log.Println("⚠ Shutdown signal received")
	log.Println("Gracefully shutting down...")
	log.Println("========================================")

	cancel()

	done := make(chan struct{})
	go func() {
		wg.Wait()
		close(done)
	}()

	select {
	case <-done:
		log.Println("✓ All in-flight messages processed")
	case <-time.After(30 * time.Second):
		log.Println("⚠ Timeout after 30s - forcing shutdown")
	}

	log.Println("✓ Payment Worker shut down gracefully")
}

func (w *Worker) processPayment(msg queue.OrderMessage) error {
	startTime := time.Now()

	log.Printf("Processing payment for order: %s, amount: $%.2f", msg.OrderID, msg.Amount)

	if err := w.db.Model(&models.Order{}).
		Where("id = ?", msg.OrderID).
		Update("status", models.StatusProcessing).Error; err != nil {
		return fmt.Errorf("failed to update order status: %w", err)
	}

	processingTime := time.Duration(100+rand.Intn(400)) * time.Millisecond
	time.Sleep(processingTime)

	paymentSuccess := rand.Float32() < 0.8

	var finalStatus models.OrderStatus
	var paymentStatus string

	if paymentSuccess {
		finalStatus = models.StatusCompleted
		paymentStatus = "success"
	} else {
		finalStatus = models.StatusFailed
		paymentStatus = "failed"
	}

	if err := w.db.Model(&models.Order{}).
		Where("id = ?", msg.OrderID).
		Update("status", finalStatus).Error; err != nil {
		return fmt.Errorf("failed to update final order status: %w", err)
	}

	payment := models.Payment{
		ID:          uuid.New().String(),
		OrderID:     msg.OrderID,
		Amount:      msg.Amount,
		Status:      paymentStatus,
		ProcessedAt: time.Now(),
	}

	if err := w.db.Create(&payment).Error; err != nil {
		log.Printf("Warning: Failed to create payment record: %v", err)
	}

	duration := time.Since(startTime)
	log.Printf("Payment %s for order %s (took %v)", paymentStatus, msg.OrderID, duration)

	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}