package models

import (
	"time"

	"github.com/google/uuid"
)

type OrderStatus string

const (
	StatusPending    OrderStatus = "pending"
	StatusProcessing OrderStatus = "processing"
	StatusCompleted  OrderStatus = "completed"
	StatusFailed     OrderStatus = "failed"
)

type Order struct {
	ID         string      `gorm:"primaryKey" json:"id"`
	CustomerID string      `json:"customer_id"`
	Items      string      `json:"items"`
	Total      float64     `json:"total"`
	Status     OrderStatus `json:"status"`
	CreatedAt  time.Time   `json:"created_at"`
	UpdatedAt  time.Time   `json:"updated_at"`
}

type Payment struct {
	ID          string    `gorm:"primaryKey" json:"id"`
	OrderID     string    `json:"order_id"`
	Amount      float64   `json:"amount"`
	Status      string    `json:"status"`
	ProcessedAt time.Time `json:"processed_at"`
}

type CreateOrderRequest struct {
	CustomerID string   `json:"customer_id" binding:"required"`
	Items      []string `json:"items" binding:"required"`
	Total      float64  `json:"total" binding:"required,gt=0"`
}

func NewOrder(customerID string, items string, total float64) *Order {
	return &Order{
		ID:         uuid.New().String(),
		CustomerID: customerID,
		Items:      items,
		Total:      total,
		Status:     StatusPending,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}
}