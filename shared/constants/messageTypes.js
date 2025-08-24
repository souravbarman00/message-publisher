export const MESSAGE_TYPES = {
  KAFKA_SNS: 'kafka-sns',
  SNS_SQS: 'sns-sqs',
  KAFKA_ONLY: 'kafka-only',
  SNS_ONLY: 'sns-only',
  SQS_ONLY: 'sqs-only'
};

export const MESSAGE_STATUS = {
  PENDING: 'pending',
  SUCCESS: 'success',
  PARTIAL: 'partial',
  ERROR: 'error',
  FAILED: 'failed'
};

export const SERVICE_NAMES = {
  KAFKA: 'kafka',
  SNS: 'sns',
  SQS: 'sqs'
};

export const PROCESSING_STATUS = {
  RECEIVED: 'received',
  PROCESSING: 'processing',
  COMPLETED: 'completed',
  FAILED: 'failed'
};
