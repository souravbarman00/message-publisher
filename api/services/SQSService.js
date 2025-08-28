import AWS from 'aws-sdk';
import dotenv from 'dotenv';
dotenv.config();


class SQSService {
  constructor() {
    // Configure AWS for SQS (ap-southeast-1)
    this.sqs = new AWS.SQS({
      apiVersion: '2012-11-05',
      region: 'ap-southeast-1',  // Hard-coded for SQS region
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    });

    this.queueUrl = process.env.SQS_QUEUE_URL;

    if (!this.queueUrl) {
      console.warn('⚠️  SQS_QUEUE_URL environment variable is not set');
    } else {
      // Test queue exists on startup
      this.testQueueExists();
    }
  }

  async testQueueExists() {
    try {
      await this.sqs.getQueueAttributes({
        QueueUrl: this.queueUrl,
        AttributeNames: ['QueueArn']
      }).promise();
      console.log('✅ SQS Queue exists and accessible');
    } catch (error) {
      console.error('❌ SQS Queue test failed:', error.message);
      console.log('Queue URL:', this.queueUrl);
    }
  }

  async sendMessage(messagePayload) {
    try {
      if (!this.queueUrl) {
        throw new Error('SQS_QUEUE_URL environment variable is not set');
      }

      const params = {
        QueueUrl: this.queueUrl,
        MessageBody: JSON.stringify(messagePayload),
        MessageAttributes: {
          'message-type': {
            DataType: 'String',
            StringValue: messagePayload.type
          },
          'message-id': {
            DataType: 'String',
            StringValue: messagePayload.id
          },
          'timestamp': {
            DataType: 'String',
            StringValue: messagePayload.timestamp
          },
          'source': {
            DataType: 'String',
            StringValue: messagePayload.source || 'unknown'
          },
          'content-type': {
            DataType: 'String',
            StringValue: 'application/json'
          }
        },
        DelaySeconds: 0
      };

      console.log(`📤 Sending message to SQS queue: ${this.queueUrl}`);

      const result = await this.sqs.sendMessage(params).promise();

      const sendResult = {
        success: true,
        messageId: result.MessageId,
        queueUrl: this.queueUrl,
        md5OfBody: result.MD5OfBody,
        timestamp: new Date().toISOString()
      };

      console.log('✅ Message sent to SQS:', sendResult);
      return sendResult;

    } catch (error) {
      console.error('❌ Error sending message to SQS:', error);
      throw new Error(`SQS send failed: ${error.message}`);
    }
  }

  async sendMessageWithDelay(messagePayload, delaySeconds) {
    try {
      if (!this.queueUrl) {
        throw new Error('SQS_QUEUE_URL environment variable is not set');
      }

      if (delaySeconds < 0 || delaySeconds > 900) {
        throw new Error('DelaySeconds must be between 0 and 900');
      }

      const params = {
        QueueUrl: this.queueUrl,
        MessageBody: JSON.stringify(messagePayload),
        MessageAttributes: {
          'message-type': {
            DataType: 'String',
            StringValue: messagePayload.type
          },
          'message-id': {
            DataType: 'String',
            StringValue: messagePayload.id
          },
          'timestamp': {
            DataType: 'String',
            StringValue: messagePayload.timestamp
          },
          'delayed': {
            DataType: 'String',
            StringValue: 'true'
          }
        },
        DelaySeconds: delaySeconds
      };

      console.log(`📤 Sending delayed message to SQS (${delaySeconds}s delay)`);

      const result = await this.sqs.sendMessage(params).promise();

      const sendResult = {
        success: true,
        messageId: result.MessageId,
        queueUrl: this.queueUrl,
        delaySeconds: delaySeconds,
        md5OfBody: result.MD5OfBody,
        timestamp: new Date().toISOString()
      };

      console.log('✅ Delayed message sent to SQS:', sendResult);
      return sendResult;

    } catch (error) {
      console.error('❌ Error sending delayed message to SQS:', error);
      throw new Error(`SQS delayed send failed: ${error.message}`);
    }
  }

  async sendMessages(messagePayloads) {
    try {
      if (!this.queueUrl) {
        throw new Error('SQS_QUEUE_URL environment variable is not set');
      }

      // SQS batch send supports max 10 messages
      const batches = [];
      for (let i = 0; i < messagePayloads.length; i += 10) {
        batches.push(messagePayloads.slice(i, i + 10));
      }

      const allResults = [];

      for (const batch of batches) {
        const entries = batch.map((payload, index) => ({
          Id: `msg-${index}`,
          MessageBody: JSON.stringify(payload),
          MessageAttributes: {
            'message-type': {
              DataType: 'String',
              StringValue: payload.type
            },
            'message-id': {
              DataType: 'String',
              StringValue: payload.id
            },
            'timestamp': {
              DataType: 'String',
              StringValue: payload.timestamp
            }
          }
        }));

        const params = {
          QueueUrl: this.queueUrl,
          Entries: entries
        };

        console.log(`📤 Sending batch of ${entries.length} messages to SQS`);

        const result = await this.sqs.sendMessageBatch(params).promise();
        allResults.push(result);
      }

      const sendResults = allResults.flatMap(result =>
        result.Successful.map(success => ({
          success: true,
          messageId: success.MessageId,
          queueUrl: this.queueUrl,
          md5OfBody: success.MD5OfBody,
          timestamp: new Date().toISOString()
        }))
      );

      console.log(`✅ ${sendResults.length} messages sent to SQS`);
      return sendResults;

    } catch (error) {
      console.error('❌ Error sending batch messages to SQS:', error);
      throw new Error(`SQS batch send failed: ${error.message}`);
    }
  }

  async receiveMessages(maxMessages = 5, waitTimeSeconds = 10) {
    try {
      if (!this.queueUrl) {
        throw new Error('SQS_QUEUE_URL environment variable is not set');
      }

      const params = {
        QueueUrl: this.queueUrl,
        MaxNumberOfMessages: maxMessages,
        WaitTimeSeconds: waitTimeSeconds,
        MessageAttributeNames: ['All']
      };

      const result = await this.sqs.receiveMessage(params).promise();

      if (!result.Messages || result.Messages.length === 0) {
        return [];
      }

      return result.Messages.map(msg => ({
        messageId: msg.MessageId,
        body: JSON.parse(msg.Body),
        attributes: msg.MessageAttributes,
        receiptHandle: msg.ReceiptHandle
      }));

    } catch (error) {
      console.error('❌ Error receiving messages from SQS:', error);
      throw new Error(`SQS receive failed: ${error.message}`);
    }
  }

  async deleteMessage(receiptHandle) {
    try {
      if (!this.queueUrl) {
        throw new Error('SQS_QUEUE_URL environment variable is not set');
      }

      const params = {
        QueueUrl: this.queueUrl,
        ReceiptHandle: receiptHandle
      };

      await this.sqs.deleteMessage(params).promise();
      console.log('✅ Message deleted from SQS');

    } catch (error) {
      console.error('❌ Error deleting message from SQS:', error);
      throw new Error(`SQS delete failed: ${error.message}`);
    }
  }

  async getQueueAttributes() {
    try {
      if (!this.queueUrl) {
        throw new Error('SQS_QUEUE_URL environment variable is not set');
      }

      const params = {
        QueueUrl: this.queueUrl,
        AttributeNames: ['All']
      };

      const result = await this.sqs.getQueueAttributes(params).promise();

      return {
        success: true,
        attributes: result.Attributes,
        queueUrl: this.queueUrl
      };

    } catch (error) {
      console.error('❌ Error getting SQS queue attributes:', error);
      throw new Error(`SQS get attributes failed: ${error.message}`);
    }
  }

  async purgeQueue() {
    try {
      if (!this.queueUrl) {
        throw new Error('SQS_QUEUE_URL environment variable is not set');
      }

      const params = {
        QueueUrl: this.queueUrl
      };

      await this.sqs.purgeQueue(params).promise();
      console.log('✅ SQS queue purged');

      return { success: true, queueUrl: this.queueUrl };

    } catch (error) {
      console.error('❌ Error purging SQS queue:', error);
      throw new Error(`SQS purge failed: ${error.message}`);
    }
  }
}

export default SQSService;
