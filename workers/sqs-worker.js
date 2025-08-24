import AWS from 'aws-sdk';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

class SQSWorker {
  constructor() {
    // Configure AWS
    AWS.config.update({
      region: process.env.AWS_REGION || 'us-east-1',
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    });

    this.sqs = new AWS.SQS({ apiVersion: '2012-11-05' });
    this.queueUrl = process.env.SQS_QUEUE_URL;
    this.pollInterval = parseInt(process.env.SQS_POLL_INTERVAL) || 5000;
    this.isRunning = false;
    this.pollingTimer = null;

    if (!this.queueUrl) {
      console.error('❌ SQS_QUEUE_URL environment variable is not set');
      process.exit(1);
    }
  }

  async start() {
    try {
      console.log('🚀 Starting SQS Worker...');
      console.log(`📍 Queue URL: ${this.queueUrl}`);
      console.log(`⏱️  Poll Interval: ${this.pollInterval}ms`);
      
      this.isRunning = true;
      await this.startPolling();
      
      console.log('✅ SQS Worker started successfully');
    } catch (error) {
      console.error('❌ Error starting SQS worker:', error);
      throw error;
    }
  }

  async startPolling() {
    const poll = async () => {
      if (!this.isRunning) return;

      try {
        await this.pollMessages();
      } catch (error) {
        console.error('❌ Error during polling:', error);
      }

      if (this.isRunning) {
        this.pollingTimer = setTimeout(poll, this.pollInterval);
      }
    };

    // Start polling immediately
    await poll();
  }

  async pollMessages() {
    try {
      console.log('🔍 Polling for SQS messages...');

      const params = {
        QueueUrl: this.queueUrl,
        MaxNumberOfMessages: 10, // Max is 10
        WaitTimeSeconds: 10, // Long polling
        MessageAttributeNames: ['All'],
        AttributeNames: ['All']
      };

      const data = await this.sqs.receiveMessage(params).promise();

      if (!data.Messages || data.Messages.length === 0) {
        console.log('📭 No messages in queue');
        return;
      }

      console.log(`📨 Received ${data.Messages.length} messages`);

      // Process messages concurrently
      const processingPromises = data.Messages.map(message => 
        this.processMessage(message)
      );

      await Promise.allSettled(processingPromises);

    } catch (error) {
      console.error('❌ SQS polling error:', error);
    }
  }

  async processMessage(message) {
    try {
      const messageBody = JSON.parse(message.Body);
      
      console.log('📨 Processing SQS message:', {
        messageId: message.MessageId,
        type: messageBody.type,
        timestamp: messageBody.timestamp,
        receiptHandle: message.ReceiptHandle?.substring(0, 20) + '...'
      });

      // Process the message based on type
      await this.handleMessageByType(messageBody);

      // Delete message after successful processing
      await this.deleteMessage(message.ReceiptHandle);
      
      console.log(`✅ Successfully processed and deleted message: ${message.MessageId}`);

    } catch (error) {
      console.error('❌ Error processing SQS message:', error);
      console.error('Message details:', {
        messageId: message.MessageId,
        body: message.Body,
        attributes: message.MessageAttributes
      });
      
      // In production, you might want to:
      // 1. Increment a retry counter in message attributes
      // 2. Send to DLQ after max retries
      // 3. Log to external monitoring system
    }
  }

  async handleMessageByType(messageData) {
    switch (messageData.type) {
      case 'sns-sqs':
        await this.processSnsToSqsMessage(messageData);
        break;
      case 'sqs-only':
        await this.processSqsOnlyMessage(messageData);
        break;
      default:
        await this.processGenericMessage(messageData);
    }
  }

  async processSnsToSqsMessage(messageData) {
    console.log('🔄 Processing SNS→SQS message:', messageData.content);
    
    // Example processing: Save to database, call API, send notification
    await this.simulateProcessing();
    
    console.log('✅ SNS→SQS message processed successfully');
  }

  async processSqsOnlyMessage(messageData) {
    console.log('🔄 Processing SQS-only message:', messageData.content);
    
    // Example processing: File processing, data transformation, etc.
    await this.simulateProcessing();
    
    console.log('✅ SQS-only message processed successfully');
  }

  async processGenericMessage(messageData) {
    console.log('🔄 Processing generic message:', messageData.content);
    
    // Generic message processing
    await this.simulateProcessing();
    
    console.log('✅ Generic message processed successfully');
  }

  async simulateProcessing() {
    // Simulate some async processing time
    const processingTime = Math.random() * 2000; // 0-2 seconds
    return new Promise(resolve => setTimeout(resolve, processingTime));
  }

  async deleteMessage(receiptHandle) {
    try {
      const params = {
        QueueUrl: this.queueUrl,
        ReceiptHandle: receiptHandle
      };

      await this.sqs.deleteMessage(params).promise();
      
    } catch (error) {
      console.error('❌ Error deleting SQS message:', error);
      throw error;
    }
  }

  async stop() {
    try {
      console.log('🔄 Stopping SQS Worker...');
      this.isRunning = false;
      
      if (this.pollingTimer) {
        clearTimeout(this.pollingTimer);
        this.pollingTimer = null;
      }
      
      console.log('✅ SQS worker stopped');
    } catch (error) {
      console.error('❌ Error stopping SQS worker:', error);
    }
  }

  async getQueueAttributes() {
    try {
      const params = {
        QueueUrl: this.queueUrl,
        AttributeNames: ['All']
      };

      const result = await this.sqs.getQueueAttributes(params).promise();
      return result.Attributes;
    } catch (error) {
      console.error('❌ Error getting queue attributes:', error);
      return null;
    }
  }

  async getWorkerStatus() {
    const attributes = await this.getQueueAttributes();
    
    return {
      isRunning: this.isRunning,
      queueUrl: this.queueUrl,
      pollInterval: this.pollInterval,
      queueAttributes: attributes ? {
        approximateNumberOfMessages: attributes.ApproximateNumberOfMessages,
        approximateNumberOfMessagesNotVisible: attributes.ApproximateNumberOfMessagesNotVisible,
        queueArn: attributes.QueueArn
      } : null
    };
  }
}

// Create and start worker
const sqsWorker = new SQSWorker();

// Graceful shutdown
const gracefulShutdown = async (signal) => {
  console.log(`\n🛑 Received ${signal}, shutting down gracefully...`);
  await sqsWorker.stop();
  process.exit(0);
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('💥 Uncaught Exception:', error);
  gracefulShutdown('uncaughtException');
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('💥 Unhandled Rejection at:', promise, 'reason:', reason);
  gracefulShutdown('unhandledRejection');
});

// Start the worker
async function main() {
  try {
    await sqsWorker.start();
    console.log('🎉 SQS Worker is running and ready to process messages!');
    
    // Log queue status every 30 seconds
    setInterval(async () => {
      if (sqsWorker.isRunning) {
        const status = await sqsWorker.getWorkerStatus();
        console.log('📊 Queue Status:', {
          messagesAvailable: status.queueAttributes?.approximateNumberOfMessages || 'unknown',
          messagesInFlight: status.queueAttributes?.approximateNumberOfMessagesNotVisible || 'unknown'
        });
      }
    }, 30000);
    
  } catch (error) {
    console.error('💥 Failed to start SQS Worker:', error);
    process.exit(1);
  }
}

main();

export default sqsWorker;
