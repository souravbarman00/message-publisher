-- Initialize database for message tracking (optional)
-- This script creates tables for tracking message processing

CREATE DATABASE IF NOT EXISTS message_publisher;
USE message_publisher;

-- Table for tracking published messages
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id VARCHAR(255) UNIQUE NOT NULL,
    message_content TEXT NOT NULL,
    message_type VARCHAR(50) NOT NULL,
    metadata JSONB,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for tracking service results
CREATE TABLE IF NOT EXISTS message_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
    service_name VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    service_message_id VARCHAR(255),
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for tracking worker processing
CREATE TABLE IF NOT EXISTS worker_processing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id VARCHAR(255) NOT NULL,
    worker_name VARCHAR(50) NOT NULL,
    status VARCHAR(20) DEFAULT 'received',
    processing_started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_completed_at TIMESTAMP,
    error_message TEXT,
    metadata JSONB
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_messages_request_id ON messages(request_id);
CREATE INDEX IF NOT EXISTS idx_messages_status ON messages(status);
CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(message_type);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

CREATE INDEX IF NOT EXISTS idx_message_results_message_id ON message_results(message_id);
CREATE INDEX IF NOT EXISTS idx_message_results_service ON message_results(service_name);
CREATE INDEX IF NOT EXISTS idx_message_results_status ON message_results(status);

CREATE INDEX IF NOT EXISTS idx_worker_processing_message_id ON worker_processing(message_id);
CREATE INDEX IF NOT EXISTS idx_worker_processing_worker ON worker_processing(worker_name);
CREATE INDEX IF NOT EXISTS idx_worker_processing_status ON worker_processing(status);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to automatically update updated_at
CREATE TRIGGER update_messages_updated_at 
    BEFORE UPDATE ON messages 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Sample data (optional for testing)
-- INSERT INTO messages (request_id, message_content, message_type, metadata, status) 
-- VALUES 
--     ('test-001', 'Hello World!', 'kafka-sns', '{"priority": "high"}', 'completed'),
--     ('test-002', 'Test Message', 'sns-sqs', '{"source": "api"}', 'pending');
