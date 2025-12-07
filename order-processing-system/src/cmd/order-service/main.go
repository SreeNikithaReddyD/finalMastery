package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"order-processing-system/internal/models"
	"order-processing-system/internal/queue"
)

type Server struct {
	db    *gorm.DB
	queue *queue.RabbitMQ
}

func main() {
	// Database connection
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "postgres")
	dbPass := getEnv("DB_PASSWORD", "postgres")
	dbName := getEnv("DB_NAME", "orders")

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
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

	// Auto migrate
	db.AutoMigrate(&models.Order{}, &models.Payment{})
	log.Println("Database connected and migrated successfully")

	// RabbitMQ connection
rabbitURL := getEnv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/")
queueName := getEnv("QUEUE_NAME", "orders")
dlqName := queueName + "_dlq"

rmq, err := queue.NewRabbitMQ(rabbitURL, queueName, dlqName)
if err != nil {
	log.Fatalf("Failed to connect to RabbitMQ: %v", err)
}
defer rmq.Close()
log.Println("RabbitMQ connected successfully")

	server := &Server{db: db, queue: rmq}

	// Gin router
	r := gin.Default()

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy"})
	})

	// Routes
	r.POST("/orders", server.createOrder)
	r.GET("/orders/:id", server.getOrder)
	r.GET("/orders", server.listOrders)
	r.GET("/metrics", server.getMetrics)

	port := getEnv("PORT", "8080")
	log.Printf("Starting Order Service on port %s", port)
	r.Run(":" + port)
}

func (s *Server) createOrder(c *gin.Context) {
	startTime := time.Now()

	var req models.CreateOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Convert items to JSON string
	itemsJSON, _ := json.Marshal(req.Items)

	// Create order
	order := models.NewOrder(req.CustomerID, string(itemsJSON), req.Total)

	if err := s.db.Create(order).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create order"})
		return
	}

	// Publish to queue
	msg := queue.OrderMessage{
		OrderID: order.ID,
		Amount:  order.Total,
	}

	if err := s.queue.Publish(msg); err != nil {
		log.Printf("Failed to publish message: %v", err)
	}

	duration := time.Since(startTime)
	log.Printf("Order created: %s (took %v)", order.ID, duration)

	c.JSON(http.StatusCreated, order)
}

func (s *Server) getOrder(c *gin.Context) {
	id := c.Param("id")

	var order models.Order
	if err := s.db.First(&order, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	c.JSON(http.StatusOK, order)
}

func (s *Server) listOrders(c *gin.Context) {
	var orders []models.Order

	limit := 100
	if err := s.db.Order("created_at desc").Limit(limit).Find(&orders).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch orders"})
		return
	}

	c.JSON(http.StatusOK, orders)
}

func (s *Server) getMetrics(c *gin.Context) {
	var total int64
	var pending, processing, completed, failed int64

	s.db.Model(&models.Order{}).Count(&total)
	s.db.Model(&models.Order{}).Where("status = ?", models.StatusPending).Count(&pending)
	s.db.Model(&models.Order{}).Where("status = ?", models.StatusProcessing).Count(&processing)
	s.db.Model(&models.Order{}).Where("status = ?", models.StatusCompleted).Count(&completed)
	s.db.Model(&models.Order{}).Where("status = ?", models.StatusFailed).Count(&failed)

	c.JSON(http.StatusOK, gin.H{
		"total_orders": total,
		"pending":      pending,
		"processing":   processing,
		"completed":    completed,
		"failed":       failed,
	})
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}