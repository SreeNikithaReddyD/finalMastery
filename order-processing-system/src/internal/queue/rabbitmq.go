package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

type RabbitMQ struct {
	conn       *amqp.Connection
	channel    *amqp.Channel
	queue      string
	dlqName    string
	maxRetries int
	prefetch   int
}

type OrderMessage struct {
	OrderID    string  `json:"order_id"`
	Amount     float64 `json:"amount"`
	RetryCount int     `json:"retry_count"`
}

func NewRabbitMQ(url, queueName, dlqName string) (*RabbitMQ, error) {
	return NewRabbitMQWithPrefetch(url, queueName, dlqName, 10)
}

func NewRabbitMQWithPrefetch(url, queueName, dlqName string, prefetch int) (*RabbitMQ, error) {
	var conn *amqp.Connection
	var err error

	for i := 0; i < 5; i++ {
		conn, err = amqp.Dial(url)
		if err == nil {
			break
		}
		log.Printf("Failed to connect to RabbitMQ (attempt %d/5): %v", i+1, err)
		time.Sleep(time.Duration(i+1) * 2 * time.Second)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to connect to RabbitMQ after retries: %w", err)
	}

	channel, err := conn.Channel()
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("failed to open channel: %w", err)
	}

	err = channel.Qos(prefetch, 0, false)
	if err != nil {
		channel.Close()
		conn.Close()
		return nil, fmt.Errorf("failed to set QoS: %w", err)
	}
	log.Printf("✓ Prefetch limit set to %d (concurrent processing)", prefetch)

	_, err = channel.QueueDeclare(dlqName, true, false, false, false, nil)
	if err != nil {
		channel.Close()
		conn.Close()
		return nil, fmt.Errorf("failed to declare DLQ: %w", err)
	}
	log.Printf("✓ Dead-letter queue created: %s", dlqName)

	_, err = channel.QueueDeclare(
		queueName,
		true,
		false,
		false,
		false,
		amqp.Table{
			"x-dead-letter-exchange":    "",
			"x-dead-letter-routing-key": dlqName,
		},
	)
	if err != nil {
		channel.Close()
		conn.Close()
		return nil, fmt.Errorf("failed to declare queue: %w", err)
	}

	log.Printf("✓ Main queue configured: %s -> %s (DLX)", queueName, dlqName)

	return &RabbitMQ{
		conn:       conn,
		channel:    channel,
		queue:      queueName,
		dlqName:    dlqName,
		maxRetries: 3,
		prefetch:   prefetch,
	}, nil
}

func (r *RabbitMQ) Publish(message OrderMessage) error {
	body, err := json.Marshal(message)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	err = r.channel.Publish(
		"",
		r.queue,
		false,
		false,
		amqp.Publishing{
			DeliveryMode: amqp.Persistent,
			ContentType:  "application/json",
			Body:         body,
		},
	)

	return err
}

func (r *RabbitMQ) ConsumeWithContext(ctx context.Context, wg *sync.WaitGroup, handler func(OrderMessage) error) error {
	msgs, err := r.channel.Consume(r.queue, "", false, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("failed to register consumer: %w", err)
	}

	log.Printf("✓ Consumer started (prefetch=%d, concurrent processing enabled)", r.prefetch)

	sem := make(chan struct{}, r.prefetch)

	for {
		select {
		case <-ctx.Done():
			log.Println("⚠ Context cancelled - stopping message consumption")
			return nil

		case msg, ok := <-msgs:
			if !ok {
				log.Println("⚠ Channel closed - stopping consumer")
				return nil
			}

			sem <- struct{}{}
			wg.Add(1)

			go func(delivery amqp.Delivery) {
				defer wg.Done()
				defer func() { <-sem }()

				var orderMsg OrderMessage
				if err := json.Unmarshal(delivery.Body, &orderMsg); err != nil {
					log.Printf("✗ Invalid message format: %v", err)
					delivery.Nack(false, false)
					return
				}

				log.Printf("→ Processing order %s (retry %d/%d)",
					orderMsg.OrderID, orderMsg.RetryCount, r.maxRetries)

				err := handler(orderMsg)

				if err != nil {
					orderMsg.RetryCount++

					if orderMsg.RetryCount >= r.maxRetries {
						log.Printf("✗ Max retries (%d) exceeded for order %s - sending to DLQ",
							r.maxRetries, orderMsg.OrderID)
						delivery.Nack(false, false)
						return
					}

					backoff := time.Duration(orderMsg.RetryCount*orderMsg.RetryCount) * time.Second
					log.Printf("⟳ Retry %d/%d for order %s after %v",
						orderMsg.RetryCount, r.maxRetries, orderMsg.OrderID, backoff)

					time.Sleep(backoff)

					body, _ := json.Marshal(orderMsg)
					r.channel.Publish("", r.queue, false, false, amqp.Publishing{
						DeliveryMode: amqp.Persistent,
						ContentType:  "application/json",
						Body:         body,
					})

					delivery.Ack(false)
					return
				}

				delivery.Ack(false)
				log.Printf("✓ Successfully processed order %s", orderMsg.OrderID)
			}(msg)
		}
	}
}

func (r *RabbitMQ) Consume(handler func(OrderMessage) error) error {
	ctx := context.Background()
	var wg sync.WaitGroup
	return r.ConsumeWithContext(ctx, &wg, handler)
}

func (r *RabbitMQ) Close() {
	if r.channel != nil {
		r.channel.Close()
	}
	if r.conn != nil {
		r.conn.Close()
	}
	log.Println("✓ RabbitMQ connection closed")
}