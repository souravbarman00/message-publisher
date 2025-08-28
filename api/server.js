import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
dotenv.config();
// Import routes
import publisherRoutes from './routes/publisher.js';
import healthRoutes from './routes/health.js';

// Load environment variables


// Debug environment variables
console.log('🔍 Debug Environment Variables:');
console.log('SNS_TOPIC_ARN:', process.env.SNS_TOPIC_ARN);
console.log('SNS_TOPIC_ARN length:', process.env.SNS_TOPIC_ARN?.length);
console.log('SNS_TOPIC_ARN JSON:', JSON.stringify(process.env.SNS_TOPIC_ARN));
console.log('AWS_REGION:', process.env.AWS_REGION);
console.log('PORT:', process.env.PORT);

const app = express();
const PORT = process.env.PORT || 4000;

// Middleware
app.use(helmet()); // Security headers
app.use(cors()); // Enable CORS
app.use(morgan('combined')); // Request logging
app.use(express.json()); // Parse JSON bodies
app.use(express.urlencoded({ extended: true })); // Parse URL-encoded bodies

// Serve static files
app.use(express.static('public'));

// Routes
app.use('/api/health', healthRoutes);
app.use('/api/publisher', publisherRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Message Publisher API',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/api/health',
      publisher: '/api/publisher',
      docs: '/api/docs'
    }
  });
});

// API Documentation
app.get('/api/docs', (req, res) => {
  res.json({
    title: 'Message Publisher API Documentation',
    version: '1.0.0',
    endpoints: [
      {
        path: '/api/publisher/kafka-sns',
        method: 'POST',
        description: 'Publish message to both Kafka and SNS',
        body: {
          message: 'string (required)',
          metadata: 'object (optional)'
        }
      },
      {
        path: '/api/publisher/sns-sqs',
        method: 'POST',
        description: 'Publish message to SNS and send to SQS',
        body: {
          message: 'string (required)',
          metadata: 'object (optional)'
        }
      },
      {
        path: '/api/publisher/kafka',
        method: 'POST',
        description: 'Publish message to Kafka only',
        body: {
          message: 'string (required)',
          metadata: 'object (optional)'
        }
      },
      {
        path: '/api/publisher/sns',
        method: 'POST',
        description: 'Publish message to SNS only',
        body: {
          message: 'string (required)',
          metadata: 'object (optional)'
        }
      },
      {
        path: '/api/publisher/sqs',
        method: 'POST',
        description: 'Send message to SQS only',
        body: {
          message: 'string (required)',
          metadata: 'object (optional)'
        }
      }
    ]
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Route not found',
    method: req.method,
    url: req.originalUrl,
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((err, req, res, _next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
    timestamp: new Date().toISOString()
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Message Publisher API is running on port ${PORT}`);
  console.log(`📍 Local: http://localhost:${PORT}`);
  console.log(`🏥 Health check: http://localhost:${PORT}/api/health`);
  console.log(`📚 API docs: http://localhost:${PORT}/api/docs`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\\n🔄 Shutting down gracefully...');
  // eslint-disable-next-line n/no-process-exit
  process.exit(0);

});

export default app;
