import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import KafkaService from '../services/KafkaService.js';
import SNSService from '../services/SNSService.js';
import SQSService from '../services/SQSService.js';

const router = express.Router();

// Initialize services
const kafkaService = new KafkaService();
const snsService = new SNSService();
const sqsService = new SQSService();

// Middleware for request validation
const validateMessage = (req, res, next) => {
  const { message } = req.body;

  if (!message || typeof message !== 'string' || message.trim().length === 0) {
    return res.status(400).json({
      error: 'Message is required and must be a non-empty string',
      timestamp: new Date().toISOString()
    });
  }

  next();
};

// Route: Kafka + SNS
router.post('/kafka-sns', validateMessage, async (req, res) => {
  const requestId = uuidv4();
  const { message, metadata = {} } = req.body;

  console.log(`[${requestId}] Processing Kafka + SNS request`);
  console.log('Environment check:', {
    kafkaTopicSet: Boolean(process.env.KAFKA_TOPIC),
    snsTopicSet: Boolean(process.env.SNS_TOPIC_ARN),
    awsRegionSet: Boolean(process.env.AWS_REGION)
  });

  try {
    const messagePayload = {
      id: requestId,
      content: message,
      metadata,
      timestamp: new Date().toISOString(),
      type: 'kafka-sns',
      source: 'message-publisher-api'
    };

    // Publish to both services concurrently
    const [kafkaResult, snsResult] = await Promise.allSettled([
      kafkaService.publishMessage(messagePayload),
      snsService.publishMessage(messagePayload)
    ]);

    // Check results
    const response = {
      success: true,
      requestId,
      message: 'Message processing completed',
      timestamp: new Date().toISOString(),
      results: {}
    };

    if (kafkaResult.status === 'fulfilled') {
      response.results.kafka = {
        status: 'success',
        ...kafkaResult.value
      };
    } else {
      response.results.kafka = {
        status: 'failed',
        error: kafkaResult.reason.message
      };
      response.success = false;
    }

    if (snsResult.status === 'fulfilled') {
      response.results.sns = {
        status: 'success',
        ...snsResult.value
      };
    } else {
      response.results.sns = {
        status: 'failed',
        error: snsResult.reason.message
      };
      response.success = false;
    }

    const statusCode = response.success ? 200 : 207; // 207 for partial success
    res.status(statusCode).json(response);

  } catch (error) {
    console.error(`[${requestId}] Error in Kafka + SNS:`, error);
    res.status(500).json({
      success: false,
      requestId,
      error: 'Internal server error',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Route: SNS + SQS
router.post('/sns-sqs', validateMessage, async (req, res) => {
  const requestId = uuidv4();
  const { message, metadata = {} } = req.body;

  console.log(`[${requestId}] Processing SNS + SQS request`);

  try {
    const messagePayload = {
      id: requestId,
      content: message,
      metadata,
      timestamp: new Date().toISOString(),
      type: 'sns-sqs',
      source: 'message-publisher-api'
    };

    // Publish to both services concurrently
    const [snsResult, sqsResult] = await Promise.allSettled([
      snsService.publishMessage(messagePayload),
      sqsService.sendMessage(messagePayload)
    ]);

    // Check results
    const response = {
      success: true,
      requestId,
      message: 'Message processing completed',
      timestamp: new Date().toISOString(),
      results: {}
    };

    if (snsResult.status === 'fulfilled') {
      response.results.sns = {
        status: 'success',
        ...snsResult.value
      };
    } else {
      response.results.sns = {
        status: 'failed',
        error: snsResult.reason.message
      };
      response.success = false;
    }

    if (sqsResult.status === 'fulfilled') {
      response.results.sqs = {
        status: 'success',
        ...sqsResult.value
      };
    } else {
      response.results.sqs = {
        status: 'failed',
        error: sqsResult.reason.message
      };
      response.success = false;
    }

    const statusCode = response.success ? 200 : 207; // 207 for partial success
    res.status(statusCode).json(response);

  } catch (error) {
    console.error(`[${requestId}] Error in SNS + SQS:`, error);
    res.status(500).json({
      success: false,
      requestId,
      error: 'Internal server error',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Route: Kafka only
router.post('/kafka', validateMessage, async (req, res) => {
  const requestId = uuidv4();
  const { message, metadata = {} } = req.body;

  console.log(`[${requestId}] Processing Kafka request`);

  try {
    const messagePayload = {
      id: requestId,
      content: message,
      metadata,
      timestamp: new Date().toISOString(),
      type: 'kafka-only',
      source: 'message-publisher-api'
    };

    const result = await kafkaService.publishMessage(messagePayload);

    res.json({
      success: true,
      requestId,
      message: 'Message published to Kafka successfully',
      timestamp: new Date().toISOString(),
      result
    });

  } catch (error) {
    console.error(`[${requestId}] Error publishing to Kafka:`, error);
    res.status(500).json({
      success: false,
      requestId,
      error: 'Failed to publish message to Kafka',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Route: SNS only
router.post('/sns', validateMessage, async (req, res) => {
  const requestId = uuidv4();
  const { message, metadata = {} } = req.body;

  console.log(`[${requestId}] Processing SNS request`);

  try {
    const messagePayload = {
      id: requestId,
      content: message,
      metadata,
      timestamp: new Date().toISOString(),
      type: 'sns-only',
      source: 'message-publisher-api'
    };

    const result = await snsService.publishMessage(messagePayload);

    res.json({
      success: true,
      requestId,
      message: 'Message published to SNS successfully',
      timestamp: new Date().toISOString(),
      result
    });

  } catch (error) {
    console.error(`[${requestId}] Error publishing to SNS:`, error);
    res.status(500).json({
      success: false,
      requestId,
      error: 'Failed to publish message to SNS',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Route: SQS only
router.post('/sqs', validateMessage, async (req, res) => {
  const requestId = uuidv4();
  const { message, metadata = {} } = req.body;

  console.log(`[${requestId}] Processing SQS request`);

  try {
    const messagePayload = {
      id: requestId,
      content: message,
      metadata,
      timestamp: new Date().toISOString(),
      type: 'sqs-only',
      source: 'message-publisher-api'
    };

    const result = await sqsService.sendMessage(messagePayload);

    res.json({
      success: true,
      requestId,
      message: 'Message sent to SQS successfully',
      timestamp: new Date().toISOString(),
      result
    });

  } catch (error) {
    console.error(`[${requestId}] Error sending to SQS:`, error);
    res.status(500).json({
      success: false,
      requestId,
      error: 'Failed to send message to SQS',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Get publisher status
router.get('/status', async (req, res) => {
  try {
    const status = {
      timestamp: new Date().toISOString(),
      services: {
        kafka: 'checking...',
        sns: 'checking...',
        sqs: 'checking...'
      }
    };

    // TODO: Implement actual health checks for each service
    status.services.kafka = 'available';
    status.services.sns = 'available';
    status.services.sqs = 'available';

    res.json(status);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to get publisher status',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

export default router;
