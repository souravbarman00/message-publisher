import { Kafka } from 'kafkajs';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

class KafkaWorker {
  constructor() {
    this.kafka = new Kafka({
      clientId: 'message-publisher-kafka-worker',
      brokers: process.env.KAFKA_BROKERS ? process.env.KAFKA_BROKERS.split(',') : ['localhost:9092'],
      retry: {
        initialRetryTime: 100,
        retries: 8
      }
    });

    this.consumer = this.kafka.consumer({ 
      groupId: process.env.KAFKA_CONSUMER_GROUP || 'message-publisher-workers',
      sessionTimeout: 30000,
      heartbeatInterval: 3000
    });

    this.topic = process.env.KAFKA_TOPIC || 'messages';
    this.isRunning = false;
  }

  async start() {
    try {
      console.log('🚀 Starting Kafka Worker...');
      
      await this.consumer.connect();
      console.log('✅ Kafka consumer connected');

      await this.consumer.subscribe({ topic: this.topic, fromBeginning: false });
      console.log(`✅ Subscribed to topic: ${this.topic}`);

      this.isRunning = true;

      await this.consumer.run({
        eachMessage: async ({ topic, partition, message }) => {
          await this.processMessage({ topic, partition, message });
        },
        eachBatch: async ({ batch }) => {
          console.log(`📦 Processing batch of ${batch.messages.length} messages`);
          for (const message of batch.messages) {
            await this.processMessage({
              topic: batch.topic,
              partition: batch.partition,
              message
            });
          }
        }
      });

    } catch (error) {
      console.error('❌ Error starting Kafka worker:', error);
      throw error;
    }
  }

  async processMessage({ topic, partition, message }) {
    try {
      const messageValue = message.value?.toString();
      if (!messageValue) {
        console.warn('⚠️  Received empty message');
        return;
      }

      const messageData = JSON.parse(messageValue);
      const messageKey = message.key?.toString();
      
      console.log('📨 Processing Kafka message:', {
        topic,
        partition,
        offset: message.offset,
        key: messageKey,
        messageId: messageData.id,
        type: messageData.type,
        timestamp: messageData.timestamp
      });

      // Process the message based on type
      await this.handleMessageByType(messageData);

      console.log(`✅ Successfully processed message: ${messageData.id}`);

    } catch (error) {
      console.error('❌ Error processing Kafka message:', error);
      console.error('Message details:', {
        topic,
        partition,
        offset: message.offset,
        key: message.key?.toString(),
        value: message.value?.toString()
      });
      
      // In production, you might want to send failed messages to a DLQ
      // or implement retry logic
    }
  }

  async handleMessageByType(messageData) {
    switch (messageData.type) {
      case 'kafka-sns':
        await this.processKafkaSnsMessage(messageData);
        break;
      case 'kafka-only':
        await this.processKafkaOnlyMessage(messageData);
        break;
      default:
        await this.processGenericMessage(messageData);
    }
  }

  async processKafkaSnsMessage(messageData) {
    console.log('🔄 Processing Kafka+SNS message:', messageData.content);
    
    // Example: Save to database, call external API, etc.
    await this.simulateProcessing();
    
    console.log('✅ Kafka+SNS message processed successfully');
  }

  async processKafkaOnlyMessage(messageData) {
    console.log('🔄 Processing Kafka-only message:', messageData.content);
    
    // Example: Save to database, send email, etc.
    await this.simulateProcessing();
    
    console.log('✅ Kafka-only message processed successfully');
  }

  async processGenericMessage(messageData) {
    console.log('🔄 Processing generic message:', messageData.content);
    
    // Generic message processing
    await this.simulateProcessing();
    
    console.log('✅ Generic message processed successfully');
  }

  async simulateProcessing() {
    // Simulate some async processing time
    return new Promise(resolve => setTimeout(resolve, Math.random() * 1000));
  }

  async stop() {
    try {
      console.log('🔄 Stopping Kafka Worker...');
      this.isRunning = false;
      
      await this.consumer.disconnect();
      console.log('✅ Kafka worker stopped');
    } catch (error) {
      console.error('❌ Error stopping Kafka worker:', error);
    }
  }

  async getConsumerStatus() {
    return {
      isRunning: this.isRunning,
      topic: this.topic,
      groupId: process.env.KAFKA_CONSUMER_GROUP || 'message-publisher-workers'
    };
  }
}

// Create and start worker
const kafkaWorker = new KafkaWorker();

// Graceful shutdown
const gracefulShutdown = async (signal) => {
  console.log(`\n🛑 Received ${signal}, shutting down gracefully...`);
  await kafkaWorker.stop();
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
    await kafkaWorker.start();
    console.log('🎉 Kafka Worker is running and ready to process messages!');
  } catch (error) {
    console.error('💥 Failed to start Kafka Worker:', error);
    process.exit(1);
  }
}

main();

export default kafkaWorker;
