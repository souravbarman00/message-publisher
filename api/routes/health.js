import express from 'express';

const router = express.Router();

// Health check endpoint
router.get('/', (req, res) => {
  const healthStatus = {
    status: 'OK',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    service: 'Message Publisher API',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    memory: process.memoryUsage(),
    services: {
      kafka: 'checking...',
      aws: 'checking...'
    }
  };

  // Quick service checks
  try {
    // Check if AWS credentials are configured
    if (process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY) {
      healthStatus.services.aws = 'configured';
    } else {
      healthStatus.services.aws = 'not configured';
    }

    // Check if Kafka brokers are configured
    if (process.env.KAFKA_BROKERS) {
      healthStatus.services.kafka = 'configured';
    } else {
      healthStatus.services.kafka = 'not configured';
    }

    res.json(healthStatus);
  } catch (error) {
    res.status(503).json({
      ...healthStatus,
      status: 'ERROR',
      error: error.message
    });
  }
});

// Detailed health check
router.get('/detailed', async (req, res) => {
  const detailedHealth = {
    status: 'OK',
    timestamp: new Date().toISOString(),
    service: 'Message Publisher API',
    checks: {
      environment: 'OK',
      dependencies: {}
    }
  };

  try {
    // Environment check
    const requiredEnvVars = [
      'AWS_REGION',
      'KAFKA_BROKERS',
      'SNS_TOPIC_ARN',
      'SQS_QUEUE_URL'
    ];

    const missingEnvVars = requiredEnvVars.filter(envVar => !process.env[envVar]);
    if (missingEnvVars.length > 0) {
      detailedHealth.checks.environment = `Missing: ${missingEnvVars.join(', ')}`;
      detailedHealth.status = 'WARNING';
    }

    // TODO: Add actual connection checks for Kafka and AWS services
    detailedHealth.checks.dependencies = {
      kafka: 'Not tested - implement connection check',
      aws_sns: 'Not tested - implement connection check',
      aws_sqs: 'Not tested - implement connection check'
    };

    res.json(detailedHealth);
  } catch (error) {
    res.status(503).json({
      ...detailedHealth,
      status: 'ERROR',
      error: error.message
    });
  }
});

export default router;
