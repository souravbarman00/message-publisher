import AWS from 'aws-sdk';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

class SNSWorker {
  constructor() {
    // Configure AWS
    AWS.config.update({
      region: process.env.AWS_REGION,
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    });

    this.sns = new AWS.SNS({ apiVersion: '2010-03-31' });
    this.topicArn = process.env.SNS_TOPIC_ARN;
    this.pollInterval = parseInt(process.env.SNS_POLL_INTERVAL) || 10000;
    this.isRunning = false;
    this.pollingTimer = null;
    this.processedMessages = [];
    this.maxHistorySize = 100;

    if (!this.topicArn) {
      console.warn('⚠️  SNS_TOPIC_ARN environment variable is not set');
      console.log('ℹ️  SNS Worker will run in monitoring mode only');
    }
  }

  async start() {
    try {
      console.log('🚀 Starting SNS Worker...');
      console.log(`📍 Topic ARN: ${this.topicArn || 'Not configured'}`);
      console.log(`⏱️  Poll Interval: ${this.pollInterval}ms`);
      
      this.isRunning = true;
      await this.startMonitoring();
      
      console.log('✅ SNS Worker started successfully');
    } catch (error) {
      console.error('❌ Error starting SNS worker:', error);
      throw error;
    }
  }

  async startMonitoring() {
    const monitor = async () => {
      if (!this.isRunning) return;

      try {
        await this.checkTopicStatus();
        await this.processNotifications();
      } catch (error) {
        console.error('❌ Error during monitoring:', error);
      }

      if (this.isRunning) {
        this.pollingTimer = setTimeout(monitor, this.pollInterval);
      }
    };

    // Start monitoring immediately
    await monitor();
  }

  async checkTopicStatus() {
    if (!this.topicArn) return;

    try {
      const params = {
        TopicArn: this.topicArn
      };

      const attributes = await this.sns.getTopicAttributes(params).promise();
      
      // Log topic statistics occasionally
      if (Math.random() < 0.1) { // 10% chance to log
        console.log('📊 SNS Topic Status:', {
          subscriptionsConfirmed: attributes.Attributes.SubscriptionsConfirmed,
          subscriptionsPending: attributes.Attributes.SubscriptionsPending,
          topicArn: this.topicArn.split(':').pop() // Just show the topic name
        });
      }
      
    } catch (error) {
      console.error('❌ Error checking topic status:', error);
    }
  }

  async processNotifications() {
    // In a real SNS worker, you might:
    // 1. Process webhook notifications from SNS subscriptions
    // 2. Monitor delivery status
    // 3. Handle bounced emails or failed SMS
    // 4. Update delivery statistics
    
    // For this demo, we'll simulate processing any queued notifications
    await this.simulateNotificationProcessing();
  }

  async simulateNotificationProcessing() {
    // Simulate processing notifications that might be queued
    // In production, this could be:
    // - Processing delivery receipts
    // - Handling bounce notifications
    // - Processing subscription confirmations
    // - Updating delivery metrics
    
    if (Math.random() < 0.3) { // 30% chance to simulate processing
      const mockNotification = {
        id: `notif-${Date.now()}`,
        type: 'delivery-receipt',
        status: Math.random() > 0.1 ? 'delivered' : 'failed',
        timestamp: new Date().toISOString()
      };

      await this.processNotification(mockNotification);
    }
  }

  async processNotification(notification) {
    try {
      console.log('📨 Processing SNS notification:', {
        id: notification.id,
        type: notification.type,
        status: notification.status
      });

      switch (notification.type) {
        case 'delivery-receipt':
          await this.processDeliveryReceipt(notification);
          break;
        case 'bounce':
          await this.processBounceNotification(notification);
          break;
        case 'complaint':
          await this.processComplaintNotification(notification);
          break;
        default:
          await this.processGenericNotification(notification);
      }

      // Store processed notification in history
      this.addToHistory(notification);
      
      console.log(`✅ Successfully processed notification: ${notification.id}`);

    } catch (error) {
      console.error('❌ Error processing SNS notification:', error);
    }
  }

  async processDeliveryReceipt(notification) {
    console.log('📬 Processing delivery receipt:', notification.status);
    
    // Example: Update delivery statistics in database
    await this.simulateProcessing();
    
    if (notification.status === 'delivered') {
      console.log('✅ Message delivery confirmed');
    } else {
      console.log('❌ Message delivery failed');
    }
  }

  async processBounceNotification(notification) {
    console.log('⚠️  Processing bounce notification');
    
    // Example: Mark email as invalid, update subscriber status
    await this.simulateProcessing();
    
    console.log('✅ Bounce notification processed');
  }

  async processComplaintNotification(notification) {
    console.log('🚫 Processing complaint notification');
    
    // Example: Remove from mailing list, log complaint
    await this.simulateProcessing();
    
    console.log('✅ Complaint notification processed');
  }

  async processGenericNotification(notification) {
    console.log('🔄 Processing generic notification');
    
    // Generic notification processing
    await this.simulateProcessing();
    
    console.log('✅ Generic notification processed');
  }

  async simulateProcessing() {
    // Simulate some async processing time
    const processingTime = Math.random() * 1000; // 0-1 second
    return new Promise(resolve => setTimeout(resolve, processingTime));
  }

  addToHistory(notification) {
    this.processedMessages.unshift({
      ...notification,
      processedAt: new Date().toISOString()
    });

    // Keep only recent history
    if (this.processedMessages.length > this.maxHistorySize) {
      this.processedMessages = this.processedMessages.slice(0, this.maxHistorySize);
    }
  }

  async listSubscriptions() {
    if (!this.topicArn) return [];

    try {
      const params = {
        TopicArn: this.topicArn
      };

      const result = await this.sns.listSubscriptionsByTopic(params).promise();
      return result.Subscriptions;
    } catch (error) {
      console.error('❌ Error listing subscriptions:', error);
      return [];
    }
  }

  async stop() {
    try {
      console.log('🔄 Stopping SNS Worker...');
      this.isRunning = false;
      
      if (this.pollingTimer) {
        clearTimeout(this.pollingTimer);
        this.pollingTimer = null;
      }
      
      console.log('✅ SNS worker stopped');
    } catch (error) {
      console.error('❌ Error stopping SNS worker:', error);
    }
  }

  async getWorkerStatus() {
    const subscriptions = await this.listSubscriptions();
    
    return {
      isRunning: this.isRunning,
      topicArn: this.topicArn,
      pollInterval: this.pollInterval,
      subscriptionsCount: subscriptions.length,
      processedMessagesCount: this.processedMessages.length,
      recentActivity: this.processedMessages.slice(0, 5) // Last 5 processed
    };
  }

  getProcessingHistory() {
    return this.processedMessages;
  }

  clearHistory() {
    this.processedMessages = [];
    console.log('🗑️  Processing history cleared');
  }
}

// Create and start worker
const snsWorker = new SNSWorker();

// Graceful shutdown
const gracefulShutdown = async (signal) => {
  console.log(`\n🛑 Received ${signal}, shutting down gracefully...`);
  await snsWorker.stop();
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
    await snsWorker.start();
    console.log('🎉 SNS Worker is running and ready to process notifications!');
    
    // Log worker status every 60 seconds
    setInterval(async () => {
      if (snsWorker.isRunning) {
        const status = await snsWorker.getWorkerStatus();
        console.log('📊 SNS Worker Status:', {
          subscriptions: status.subscriptionsCount,
          processedMessages: status.processedMessagesCount,
          recentActivity: status.recentActivity.length
        });
      }
    }, 60000);
    
  } catch (error) {
    console.error('💥 Failed to start SNS Worker:', error);
    process.exit(1);
  }
}

main();

export default snsWorker;
