import { Kafka } from 'kafkajs';

class KafkaService {
  constructor() {
    const brokers = process.env.KAFKA_BROKERS ? process.env.KAFKA_BROKERS.split(',') : ['localhost:9092'];
    
    // Check if we need SASL authentication (for managed Kafka services)
    const kafkaConfig = {
      clientId: 'message-publisher-api',
      brokers: brokers,
      retry: {
        initialRetryTime: 100,
        retries: 8
      }
    };

    // Add SASL config if credentials are provided
    if (process.env.KAFKA_SASL_USERNAME && process.env.KAFKA_SASL_PASSWORD) {
      kafkaConfig.sasl = {
        mechanism: 'plain',
        username: process.env.KAFKA_SASL_USERNAME,
        password: process.env.KAFKA_SASL_PASSWORD
      };
      kafkaConfig.ssl = true;
    }

    this.kafka = new Kafka(kafkaConfig);
    
    this.producer = this.kafka.producer({
      maxInFlightRequests: 1,
      idempotent: true,
      transactionTimeout: 30000
    });
    
    this.isConnected = false;
    this.connectionPromise = null;
  }

  async connect() {
    if (this.isConnected) {
      return;
    }

    if (this.connectionPromise) {
      return this.connectionPromise;
    }

    this.connectionPromise = this._connect();
    return this.connectionPromise;
  }

  async _connect() {
    try {
      await this.producer.connect();
      this.isConnected = true;
      this.connectionPromise = null;
      console.log('✅ Kafka producer connected successfully');
    } catch (error) {
      this.connectionPromise = null;
      console.error('❌ Failed to connect Kafka producer:', error);
      throw new Error(`Kafka connection failed: ${error.message}`);
    }
  }

  async disconnect() {
    if (this.isConnected) {
      try {
        await this.producer.disconnect();
        this.isConnected = false;
        console.log('📴 Kafka producer disconnected');
      } catch (error) {
        console.error('Error disconnecting Kafka producer:', error);
      }
    }
  }

  async publishMessage(messagePayload) {
    try {
      await this.connect();

      const topic = process.env.KAFKA_TOPIC || 'messages';
      const messageKey = `msg-${messagePayload.id}`;
      
      const kafkaMessage = {
        key: messageKey,
        value: JSON.stringify(messagePayload),
        timestamp: Date.now().toString(),
        headers: {
          'content-type': 'application/json',
          'message-type': messagePayload.type,
          'source': messagePayload.source || 'unknown'
        }
      };

      console.log(`📤 Publishing to Kafka topic: ${topic}, key: ${messageKey}`);
      
      const result = await this.producer.send({
        topic: topic,
        messages: [kafkaMessage]
      });

      const publishResult = {
        success: true,
        topic: topic,
        partition: result[0].partition,
        offset: result[0].baseOffset,
        messageId: messagePayload.id,
        timestamp: new Date().toISOString()
      };

      console.log(`✅ Message published to Kafka:`, publishResult);
      return publishResult;

    } catch (error) {
      console.error('❌ Error publishing message to Kafka:', error);
      throw new Error(`Kafka publish failed: ${error.message}`);
    }
  }

  async createTopic(topicName, partitions = 3, replicationFactor = 1) {
    try {
      const admin = this.kafka.admin();
      await admin.connect();

      const topics = await admin.listTopics();
      
      if (!topics.includes(topicName)) {
        await admin.createTopics({
          topics: [{
            topic: topicName,
            numPartitions: partitions,
            replicationFactor: replicationFactor
          }]
        });
        console.log(`✅ Kafka topic '${topicName}' created successfully`);
      } else {
        console.log(`ℹ️  Kafka topic '${topicName}' already exists`);
      }

      await admin.disconnect();
      return { success: true, topic: topicName, created: !topics.includes(topicName) };
    } catch (error) {
      console.error('❌ Error creating Kafka topic:', error);
      throw new Error(`Failed to create topic: ${error.message}`);
    }
  }
}

// Graceful shutdown handling
process.on('SIGINT', async () => {
  console.log('🔄 Shutting down Kafka service...');
});

process.on('SIGTERM', async () => {
  console.log('🔄 Shutting down Kafka service...');
});

export default KafkaService;
