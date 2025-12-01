package queue

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

type RabbitMQ struct {
	conn    *amqp.Connection
	channel *amqp.Channel
	queue   string
}

type OrderMessage struct {
	OrderID string  `json:"order_id"`
	Amount  float64 `json:"amount"`
}

func NewRabbitMQ(url, queueName string) (*RabbitMQ, error) {
	var conn *amqp.Connection
	var err error

	// Retry connection with exponential backoff
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

	// Declare queue
	_, err = channel.QueueDeclare(
		queueName,
		true,  // durable
		false, // delete when unused
		false, // exclusive
		false, // no-wait
		nil,   // arguments
	)
	if err != nil {
		channel.Close()
		conn.Close()
		return nil, fmt.Errorf("failed to declare queue: %w", err)
	}

	return &RabbitMQ{
		conn:    conn,
		channel: channel,
		queue:   queueName,
	}, nil
}

func (r *RabbitMQ) Publish(message OrderMessage) error {
	body, err := json.Marshal(message)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	err = r.channel.Publish(
		"",      // exchange
		r.queue, // routing key
		false,   // mandatory
		false,   // immediate
		amqp.Publishing{
			DeliveryMode: amqp.Persistent,
			ContentType:  "application/json",
			Body:         body,
		},
	)

	return err
}

func (r *RabbitMQ) Consume(handler func(OrderMessage) error) error {
	msgs, err := r.channel.Consume(
		r.queue,
		"",    // consumer
		false, // auto-ack
		false, // exclusive
		false, // no-local
		false, // no-wait
		nil,   // args
	)
	if err != nil {
		return fmt.Errorf("failed to register consumer: %w", err)
	}

	log.Printf("Waiting for messages on queue: %s", r.queue)

	for msg := range msgs {
		var orderMsg OrderMessage
		if err := json.Unmarshal(msg.Body, &orderMsg); err != nil {
			log.Printf("Error unmarshaling message: %v", err)
			msg.Nack(false, false)
			continue
		}

		if err := handler(orderMsg); err != nil {
			log.Printf("Error handling message: %v", err)
			msg.Nack(false, true)
			continue
		}

		msg.Ack(false)
	}

	return nil
}

func (r *RabbitMQ) Close() {
	if r.channel != nil {
		r.channel.Close()
	}
	if r.conn != nil {
		r.conn.Close()
	}
}