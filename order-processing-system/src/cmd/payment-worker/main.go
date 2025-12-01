package main

import (
	"fmt"
	"log"
	"math/rand"
	"os"
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

	// Database connection
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "postgres")
	dbPass := getEnv("DB_PASSWORD", "postgres")
	dbName := getEnv("DB_NAME", "orders")

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPass, dbName)

	var db *gorm.DB
	var err error

	// Retry DB connection
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
	log.Println("Database connected successfully")

	worker := &Worker{db: db}

	// RabbitMQ connection
	rabbitURL := getEnv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/")
	queueName := getEnv("QUEUE_NAME", "orders")

	rmq, err := queue.NewRabbitMQ(rabbitURL, queueName)
	if err != nil {
		log.Fatalf("Failed to connect to RabbitMQ: %v", err)
	}
	defer rmq.Close()

	log.Println("Payment Worker started. Waiting for messages...")

	// Start consuming messages
	if err := rmq.Consume(worker.processPayment); err != nil {
		log.Fatalf("Failed to consume messages: %v", err)
	}
}

func (w *Worker) processPayment(msg queue.OrderMessage) error {
	startTime := time.Now()

	log.Printf("Processing payment for order: %s, amount: $%.2f", msg.OrderID, msg.Amount)

	// Update order status to processing
	if err := w.db.Model(&models.Order{}).
		Where("id = ?", msg.OrderID).
		Update("status", models.StatusProcessing).Error; err != nil {
		return fmt.Errorf("failed to update order status: %w", err)
	}

	// Simulate payment processing (100-500ms)
	processingTime := time.Duration(100+rand.Intn(400)) * time.Millisecond
	time.Sleep(processingTime)

	// Simulate payment success/failure (80% success rate)
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

	// Update order status
	if err := w.db.Model(&models.Order{}).
		Where("id = ?", msg.OrderID).
		Update("status", finalStatus).Error; err != nil {
		return fmt.Errorf("failed to update final order status: %w", err)
	}

	// Create payment record
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