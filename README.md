# Message Publisher System

A full-stack application for publishing messages to Kafka, SNS, and SQS with separate API and worker services.

## Architecture

```
message-publisher/
├── api/                    # Express.js API service
├── workers/               # Message processing workers
├── frontend/              # React frontend application
└── shared/                # Shared utilities and configs
```
## Test Push
## Services

### API Service (Port 4000)
- Express.js REST API
- Message publishing endpoints
- Health checks and monitoring
- Service orchestration

### Worker Services
- **Kafka Worker**: Consumes and processes Kafka messages
- **SQS Worker**: Polls and processes SQS messages  
- **SNS Worker**: Monitors SNS notifications and delivery status

### Frontend (Port 3000)
- React application with modern UI
- Real-time message publishing
- Message history and status tracking
- Service health monitoring

## Quick Start

### Prerequisites
- Node.js 18+
- Kafka running on localhost:9092
- AWS credentials configured
- AWS SNS topic and SQS queue created

### Setup

1. **Configure Environment Variables**
   ```bash
   # Copy and update .env files in each service
   cp api/.env.example api/.env
   cp workers/.env.example workers/.env
   ```

2. **Install Dependencies**
   ```bash
   # API Service
   cd api && npm install

   # Workers
   cd ../workers && npm install

   # Frontend
   cd ../frontend && npm install
   ```

3. **Start Services**
   ```bash
   # Terminal 1: Start API
   cd api && npm run dev

   # Terminal 2: Start Workers
   cd workers && npm run dev:all

   # Terminal 3: Start Frontend
   cd frontend && npm start
   ```

4. **Access Application**
   - Frontend: http://localhost:3000
   - API: http://localhost:4000
   - API Docs: http://localhost:4000/api/docs

## Environment Configuration

### API Service (.env)
```env
PORT=4000
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
SNS_TOPIC_ARN=arn:aws:sns:region:account:topic
SQS_QUEUE_URL=https://sqs.region.amazonaws.com/account/queue
KAFKA_BROKERS=localhost:9092
KAFKA_TOPIC=messages
```

### Workers (.env)
```env
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
SNS_TOPIC_ARN=arn:aws:sns:region:account:topic
SQS_QUEUE_URL=https://sqs.region.amazonaws.com/account/queue
KAFKA_BROKERS=localhost:9092
KAFKA_TOPIC=messages
KAFKA_CONSUMER_GROUP=message-publisher-workers
```

## API Endpoints

### Message Publishing
- `POST /api/publisher/kafka-sns` - Publish to Kafka + SNS
- `POST /api/publisher/sns-sqs` - Publish to SNS + SQS
- `POST /api/publisher/kafka` - Publish to Kafka only
- `POST /api/publisher/sns` - Publish to SNS only
- `POST /api/publisher/sqs` - Send to SQS only

### Health & Status
- `GET /api/health` - API health check
- `GET /api/publisher/status` - Publisher status

### Request Format
```json
{
  "message": "Your message content",
  "metadata": {
    "priority": "high",
    "source": "web-app",
    "userId": "12345"
  }
}
```

### Response Format
```json
{
  "success": true,
  "requestId": "uuid",
  "message": "Message processing completed",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "results": {
    "kafka": {
      "status": "success",
      "topic": "messages",
      "partition": 0,
      "offset": "12345"
    },
    "sns": {
      "status": "success",
      "messageId": "sns-message-id"
    }
  }
}
```

## Worker Behavior

### Kafka Worker
- Subscribes to configured topic
- Processes messages by type
- Supports batch processing
- Automatic offset management

### SQS Worker
- Long polling for efficiency
- Automatic message deletion after processing
- Error handling with retry logic
- Dead letter queue support (configurable)

### SNS Worker
- Monitors delivery receipts
- Processes bounce notifications
- Handles subscription confirmations
- Delivery statistics tracking

## Message Flow

1. **Frontend** sends message via API
2. **API Service** validates and publishes to selected services
3. **Workers** process messages asynchronously
4. **Frontend** displays real-time status updates

## Features

### Frontend Features
- 🎨 Modern, responsive UI with Tailwind CSS
- 🔄 Real-time message publishing
- 📊 Message history and status tracking
- 🏥 Service health monitoring
- 🎯 Multiple publishing options
- 📱 Mobile-friendly design

### API Features
- ⚡ High-performance Express.js
- 🛡️ Input validation and error handling
- 📝 Comprehensive logging
- 🔄 Concurrent message publishing
- 📊 Health checks and monitoring
- 🎯 RESTful design

### Worker Features
- 🔄 Automatic reconnection
- ⚡ Efficient message processing
- 🛡️ Error handling and recovery
- 📊 Processing statistics
- 🎯 Service-specific optimizations
- 📱 Graceful shutdown

## Development

### Running Individual Services

```bash
# API only
cd api && npm run dev

# Individual workers
cd workers && npm run dev:kafka
cd workers && npm run dev:sqs
cd workers && npm run dev:sns

# All workers
cd workers && npm run dev:all

# Frontend only
cd frontend && npm start
```

### Testing

```bash
# Test API endpoint
curl -X POST http://localhost:4000/api/publisher/kafka-sns \
  -H "Content-Type: application/json" \
  -d '{"message": "Test message", "metadata": {"test": true}}'

# Health check
curl http://localhost:4000/api/health
```

## Production Deployment

### Docker Support (Optional)
Each service can be containerized independently:

```dockerfile
# Example API Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 4000
CMD ["npm", "start"]
```

### Environment Setup
- Configure AWS credentials via IAM roles
- Set up Kafka cluster with appropriate topics
- Configure SNS topics with subscriptions
- Set up SQS queues with dead letter queues
- Use environment-specific configuration

### Monitoring
- API metrics via middleware
- Worker processing statistics
- AWS CloudWatch integration
- Custom dashboards for message flow

## Troubleshooting

### Common Issues

**Kafka Connection Failed**
- Verify Kafka is running on specified brokers
- Check network connectivity
- Validate topic exists and has proper permissions

**AWS Service Errors**
- Verify AWS credentials are correct
- Check IAM permissions for SNS/SQS
- Validate ARNs and URLs are correct

**Worker Not Processing**
- Check worker logs for errors
- Verify queue has messages
- Ensure proper consumer group configuration

### Logging
All services use structured logging with timestamps and request IDs for easy debugging.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
