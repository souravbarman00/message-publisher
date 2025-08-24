#!/bin/bash

# Initialize AWS services in LocalStack for development
# This script sets up SNS topics and SQS queues for local testing

set -e

LOCALSTACK_URL="http://localhost:4566"
TOPIC_NAME="message-publisher-topic"
QUEUE_NAME="message-publisher-queue"

echo "🚀 Initializing AWS services in LocalStack..."

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to be ready..."
until curl -s ${LOCALSTACK_URL}/health | grep -q "running"; do
  echo "Waiting for LocalStack..."
  sleep 2
done

echo "✅ LocalStack is ready!"

# Create SNS topic
echo "📡 Creating SNS topic: ${TOPIC_NAME}"
TOPIC_ARN=$(aws --endpoint-url=${LOCALSTACK_URL} sns create-topic \
  --name ${TOPIC_NAME} \
  --query 'TopicArn' \
  --output text \
  --region us-east-1)

echo "✅ SNS Topic created: ${TOPIC_ARN}"

# Create SQS queue
echo "📮 Creating SQS queue: ${QUEUE_NAME}"
QUEUE_URL=$(aws --endpoint-url=${LOCALSTACK_URL} sqs create-queue \
  --queue-name ${QUEUE_NAME} \
  --query 'QueueUrl' \
  --output text \
  --region us-east-1)

echo "✅ SQS Queue created: ${QUEUE_URL}"

# Get SQS queue ARN
QUEUE_ARN=$(aws --endpoint-url=${LOCALSTACK_URL} sqs get-queue-attributes \
  --queue-url ${QUEUE_URL} \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output text \
  --region us-east-1)

echo "📋 Queue ARN: ${QUEUE_ARN}"

# Create SNS subscription to SQS (optional)
echo "🔗 Creating SNS to SQS subscription..."
SUBSCRIPTION_ARN=$(aws --endpoint-url=${LOCALSTACK_URL} sns subscribe \
  --topic-arn ${TOPIC_ARN} \
  --protocol sqs \
  --notification-endpoint ${QUEUE_ARN} \
  --query 'SubscriptionArn' \
  --output text \
  --region us-east-1)

echo "✅ Subscription created: ${SUBSCRIPTION_ARN}"

# Set queue policy to allow SNS to send messages
echo "🔐 Setting SQS queue policy..."
QUEUE_POLICY='{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "1",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "'${QUEUE_ARN}'",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "'${TOPIC_ARN}'"
        }
      }
    }
  ]
}'

aws --endpoint-url=${LOCALSTACK_URL} sqs set-queue-attributes \
  --queue-url ${QUEUE_URL} \
  --attributes Policy="$(echo ${QUEUE_POLICY})" \
  --region us-east-1

echo "✅ Queue policy set successfully!"

# Create environment configuration
echo "📝 Generating environment configuration..."

ENV_CONFIG="# LocalStack AWS Configuration for Development
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_ENDPOINT_URL=${LOCALSTACK_URL}

# SNS Configuration
SNS_TOPIC_ARN=${TOPIC_ARN}

# SQS Configuration  
SQS_QUEUE_URL=${QUEUE_URL}

# Kafka Configuration (assuming local Kafka)
KAFKA_BROKERS=localhost:9092
KAFKA_TOPIC=messages
KAFKA_CONSUMER_GROUP=message-publisher-workers

# API Configuration
PORT=4000

# Worker Configuration
SQS_POLL_INTERVAL=5000
KAFKA_POLL_INTERVAL=1000
SNS_POLL_INTERVAL=10000
"

echo "${ENV_CONFIG}" > localstack.env
echo "✅ Environment configuration saved to localstack.env"

echo ""
echo "🎉 LocalStack setup completed!"
echo ""
echo "📋 Service Details:"
echo "   SNS Topic ARN: ${TOPIC_ARN}"
echo "   SQS Queue URL: ${QUEUE_URL}"
echo "   LocalStack URL: ${LOCALSTACK_URL}"
echo ""
echo "📝 Next Steps:"
echo "   1. Copy localstack.env to your service .env files"
echo "   2. Update your services to use the LocalStack endpoint"
echo "   3. Start your message publisher services"
echo ""
echo "🔧 Testing Commands:"
echo "   # Test SNS"
echo "   aws --endpoint-url=${LOCALSTACK_URL} sns publish --topic-arn ${TOPIC_ARN} --message 'Hello SNS!' --region us-east-1"
echo ""
echo "   # Test SQS"
echo "   aws --endpoint-url=${LOCALSTACK_URL} sqs send-message --queue-url ${QUEUE_URL} --message-body 'Hello SQS!' --region us-east-1"
echo ""
echo "   # Receive SQS messages"
echo "   aws --endpoint-url=${LOCALSTACK_URL} sqs receive-message --queue-url ${QUEUE_URL} --region us-east-1"
