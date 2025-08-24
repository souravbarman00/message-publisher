# 🚀 Message Publisher System - Complete Setup Guide

A production-ready full-stack application for publishing messages to **Kafka**, **SNS**, and **SQS** with separate API and worker services, following your existing project structure.

## 📋 Project Overview

Your message publisher system is now organized into separate, scalable services:

```
📦 message-publisher/
├── 🌐 api/                    # Express.js API service (Port 4000)
├── ⚙️  workers/               # Message processing workers  
├── 🎨 frontend/               # React frontend (Port 3000)
├── 🔧 shared/                 # Shared utilities and constants
├── 📜 scripts/                # Setup and initialization scripts
├── 🐳 docker-compose.yml      # Development environment
├── ⚡ setup.sh/.bat           # Quick setup scripts
└── 📖 README.md               # This file
```

## 🎯 Features

### ✨ Frontend (React)
- 🎨 Modern UI with Tailwind CSS and Lucide icons
- 🔄 Real-time message publishing with multiple service options
- 📊 Message history and status tracking
- 🏥 Service health monitoring
- 📱 Responsive design for all devices

### 🚀 API Service (Express.js)
- ⚡ High-performance REST API with ES modules
- 🎯 Five publishing endpoints:
  - `POST /api/publisher/kafka-sns` - Dual publishing
  - `POST /api/publisher/sns-sqs` - SNS to SQS flow
  - `POST /api/publisher/kafka` - Kafka only
  - `POST /api/publisher/sns` - SNS only
  - `POST /api/publisher/sqs` - SQS only
- 🛡️ Input validation and error handling
- 📊 Health checks and service monitoring
- 🔄 Concurrent message processing

### ⚙️ Worker Services
- **Kafka Worker**: Real-time message consumption with batching
- **SQS Worker**: Long-polling with automatic message deletion
- **SNS Worker**: Delivery monitoring and notification processing
- 🔄 Automatic reconnection and graceful shutdown
- 📊 Processing statistics and health monitoring

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ ✅
- Running Kafka instance (localhost:9092) ✅
- AWS credentials or LocalStack for development ✅

### 1. One-Command Setup
```bash
# Linux/macOS
./setup.sh setup

# Windows
setup.bat setup
```

### 2. Configure Environment
Update the `.env` files created in `api/` and `workers/` directories:

```env
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here

# SNS Configuration
SNS_TOPIC_ARN=arn:aws:sns:us-east-1:123456789012:your-topic-name

# SQS Configuration
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123456789012/your-queue-name

# Kafka Configuration
KAFKA_BROKERS=localhost:9092
KAFKA_TOPIC=messages
```

### 3. Start All Services
```bash
# One command to start everything
./setup.sh start

# Or individually:
./setup.sh start-api      # API only
./setup.sh start-workers  # Workers only  
./setup.sh start-frontend # Frontend only
```

### 4. Access Your Application
- 🌐 **Frontend**: http://localhost:3000
- 🔧 **API**: http://localhost:4000
- 📚 **API Docs**: http://localhost:4000/api/docs
- ❤️ **Health Check**: http://localhost:4000/api/health

## 🐳 Development with Docker

For a complete development environment with Kafka, LocalStack (AWS), and databases:

```bash
# Start infrastructure
docker-compose up -d

# Initialize AWS services in LocalStack
chmod +x scripts/init-localstack.sh
./scripts/init-localstack.sh

# Start your services
./setup.sh start
```

This gives you:
- 📊 **Kafka + Kafka UI**: http://localhost:8080
- ☁️ **LocalStack (AWS)**: http://localhost:4566
- 🗄️ **PostgreSQL**: localhost:5432
- 🔄 **Redis**: localhost:6379

## 🔧 API Usage Examples

### Send Message to Kafka + SNS
```bash
curl -X POST http://localhost:4000/api/publisher/kafka-sns \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello from the message publisher!",
    "metadata": {
      "priority": "high",
      "source": "api-test"
    }
  }'
```

### Response Format
```json
{
  "success": true,
  "requestId": "req_1234567890_abc123def",
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
      "messageId": "sns-msg-id-12345"
    }
  }
}
```

## 📊 Architecture Integration

Your new system integrates seamlessly with your existing project structure:

```
📁 C:\Users\saura\Documents\project\
├── 📊 kafka-demo/              # Your existing Kafka setup
├── 🔔 sns-test/                # Your existing SNS setup  
├── 🔄 sqsWorker.js             # Your existing SQS worker
├── 🌐 routes/sqs.js            # Your existing SQS routes
└── 🆕 message-publisher/       # New integrated system
    ├── api/                    # Replaces server.js functionality
    ├── workers/                # Enhances your sqsWorker.js
    └── frontend/               # New React interface
```

## 🔄 Message Flow

1. **Frontend** → User selects publishing method and sends message
2. **API Service** → Validates input and publishes to selected services
3. **Message Services** → Kafka/SNS/SQS receive and queue messages
4. **Workers** → Process messages asynchronously with error handling
5. **Frontend** → Shows real-time status updates and history

## 🛠️ Development Commands

```bash
# Install all dependencies
npm run install:all

# Start individual services
npm run dev:api       # API server
npm run dev:workers   # All workers  
npm run dev:frontend  # React app

# Start everything
npm run dev:all

# Build frontend for production
npm run build:frontend
```

## 📱 Production Deployment

### Environment Variables
Set these in your production environment:
- `NODE_ENV=production`
- AWS credentials via IAM roles (recommended)
- Kafka cluster endpoints
- SNS topic ARNs and SQS queue URLs
- Database connection strings (if using tracking)

### Docker Deployment
Each service can be containerized independently:

```dockerfile
# Example: API service
FROM node:18-alpine
WORKDIR /app
COPY api/ .
RUN npm ci --only=production
EXPOSE 4000
CMD ["npm", "start"]
```

## 🐛 Troubleshooting

### Common Issues

**🚫 Kafka Connection Failed**
```bash
# Check if Kafka is running
nc -z localhost 9092

# Start Kafka (if using Docker)
docker-compose up -d kafka
```

**❌ AWS Service Errors**
```bash
# Test AWS connectivity
aws sts get-caller-identity

# Use LocalStack for development
./scripts/init-localstack.sh
```

**⚠️ Port Already in Use**
```bash
# Check what's using the port
lsof -ti:4000
lsof -ti:3000

# Kill process if needed
kill -9 $(lsof -ti:4000)
```

## 🎉 What's New in Your System

Compared to your existing setup, this adds:

### ✅ Enhanced Features
- **Unified Frontend**: Single interface for all publishing methods
- **Concurrent Processing**: Publish to multiple services simultaneously  
- **Better Error Handling**: Partial success handling and retry logic
- **Real-time Monitoring**: Live status updates and service health checks
- **Production Ready**: Proper logging, validation, and graceful shutdown

### 🔧 Improved Architecture
- **Separation of Concerns**: API, Workers, and Frontend are independent
- **Scalability**: Each service can be scaled independently
- **Maintainability**: Shared utilities and consistent structure
- **Development Experience**: Hot reloading, easy setup, and comprehensive docs

## 🤝 Integration with Your Existing Code

Your existing files remain functional and can be gradually migrated:
- `server.js` functionality is enhanced in `api/server.js`
- `sqsWorker.js` is evolved into `workers/sqs-worker.js`
- `routes/sqs.js` patterns are expanded in `api/routes/publisher.js`
- Your Kafka and SNS demos provide the foundation for the new services

## 📞 Support

If you encounter any issues:

1. **Check the logs**: Each service provides detailed logging
2. **Run health checks**: Visit http://localhost:4000/api/health
3. **Verify configuration**: Ensure all `.env` files are properly configured
4. **Test individually**: Start one service at a time to isolate issues

## 🎯 Next Steps

1. **Configure your AWS credentials** in the `.env` files
2. **Start your existing Kafka instance** (or use Docker)
3. **Run the setup script**: `./setup.sh setup`
4. **Launch the system**: `./setup.sh start`
5. **Open the frontend**: http://localhost:3000
6. **Send your first message**! 🚀

---

**🎉 Congratulations!** Your message publisher system is now ready for development and production use!
