import AWS from 'aws-sdk';
import dotenv from 'dotenv';
dotenv.config();

class SNSService {
  constructor() {
    // Configure AWS for SNS (ap-southeast-1)
    this.sns = new AWS.SNS({
      apiVersion: '2010-03-31',
      region: 'ap-southeast-1',  // Hard-coded for SNS region
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    });

    this.topicArn = process.env.SNS_TOPIC_ARN;

    if (!this.topicArn) {
      console.warn('⚠️  SNS_TOPIC_ARN environment variable is not set');
    }
  }

  async publishMessage(messagePayload) {
    try {
      if (!this.topicArn) {
        throw new Error('SNS_TOPIC_ARN environment variable is not set');
      }

      const params = {
        TopicArn: this.topicArn,
        Message: messagePayload.content, // Send only the message content
        Subject: `Message from Publisher: ${messagePayload.type}`,
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
          }
        }
      };

      console.log(`📤 Publishing to SNS topic: ${this.topicArn}`);

      const result = await this.sns.publish(params).promise();

      const publishResult = {
        success: true,
        messageId: result.MessageId,
        topicArn: this.topicArn,
        timestamp: new Date().toISOString()
      };

      console.log('✅ Message published to SNS:', publishResult);
      return publishResult;

    } catch (error) {
      console.error('❌ Error publishing message to SNS:', error);
      throw new Error(`SNS publish failed: ${error.message}`);
    }
  }

  async publishMessageToPhone(messagePayload, phoneNumber) {
    try {
      const params = {
        PhoneNumber: phoneNumber,
        Message: messagePayload.content, // Send only the message content
        MessageAttributes: {
          'message-type': {
            DataType: 'String',
            StringValue: messagePayload.type
          },
          'message-id': {
            DataType: 'String',
            StringValue: messagePayload.id
          }
        }
      };

      console.log(`📤 Sending SMS via SNS to: ${phoneNumber}`);

      const result = await this.sns.publish(params).promise();

      const publishResult = {
        success: true,
        messageId: result.MessageId,
        phoneNumber: phoneNumber,
        timestamp: new Date().toISOString()
      };

      console.log('✅ SMS sent via SNS:', publishResult);
      return publishResult;

    } catch (error) {
      console.error('❌ Error sending SMS via SNS:', error);
      throw new Error(`SNS SMS failed: ${error.message}`);
    }
  }

  async publishMessages(messagePayloads) {
    try {
      if (!this.topicArn) {
        throw new Error('SNS_TOPIC_ARN environment variable is not set');
      }

      const publishPromises = messagePayloads.map(payload => {
        const params = {
          TopicArn: this.topicArn,
          Message: payload.content, // Send only the message content
          Subject: `Message from Publisher: ${payload.type}`,
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
        };

        return this.sns.publish(params).promise();
      });

      console.log(`📤 Publishing ${messagePayloads.length} messages to SNS`);

      const results = await Promise.all(publishPromises);

      const publishResults = results.map((result, index) => ({
        success: true,
        messageId: result.MessageId,
        originalMessageId: messagePayloads[index].id,
        topicArn: this.topicArn,
        timestamp: new Date().toISOString()
      }));

      console.log(`✅ ${publishResults.length} messages published to SNS`);
      return publishResults;

    } catch (error) {
      console.error('❌ Error publishing messages to SNS:', error);
      throw new Error(`SNS batch publish failed: ${error.message}`);
    }
  }

  async listTopics() {
    try {
      const result = await this.sns.listTopics().promise();
      return result.Topics;
    } catch (error) {
      console.error('❌ Error listing SNS topics:', error);
      throw new Error(`Failed to list SNS topics: ${error.message}`);
    }
  }

  async getTopicAttributes(topicArn) {
    try {
      const params = {
        TopicArn: topicArn || this.topicArn
      };

      const result = await this.sns.getTopicAttributes(params).promise();
      return result.Attributes;
    } catch (error) {
      console.error('❌ Error getting topic attributes:', error);
      throw new Error(`Failed to get topic attributes: ${error.message}`);
    }
  }

  async createTopic(topicName) {
    try {
      const params = {
        Name: topicName
      };

      const result = await this.sns.createTopic(params).promise();

      console.log(`✅ SNS topic '${topicName}' created: ${result.TopicArn}`);
      return {
        success: true,
        topicArn: result.TopicArn,
        topicName: topicName
      };
    } catch (error) {
      console.error('❌ Error creating SNS topic:', error);
      throw new Error(`Failed to create SNS topic: ${error.message}`);
    }
  }
}

export default SNSService;
