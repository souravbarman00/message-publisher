/**
 * Logger utility with structured logging
 */
class Logger {
  constructor(serviceName) {
    this.serviceName = serviceName;
  }

  log(level, message, data = {}) {
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      level,
      service: this.serviceName,
      message,
      ...data
    };
    
    console.log(JSON.stringify(logEntry));
  }

  info(message, data) {
    this.log('INFO', message, data);
  }

  warn(message, data) {
    this.log('WARN', message, data);
  }

  error(message, data) {
    this.log('ERROR', message, data);
  }

  debug(message, data) {
    if (process.env.LOG_LEVEL === 'debug' || process.env.NODE_ENV === 'development') {
      this.log('DEBUG', message, data);
    }
  }
}

/**
 * Create a logger instance for a service
 * @param {string} serviceName - Name of the service
 * @returns {Logger} Logger instance
 */
export function createLogger(serviceName) {
  return new Logger(serviceName);
}

/**
 * Format error for logging
 * @param {Error} error - Error object
 * @returns {Object} Formatted error data
 */
export function formatError(error) {
  return {
    name: error.name,
    message: error.message,
    stack: error.stack,
    timestamp: new Date().toISOString()
  };
}

/**
 * Generate request ID for tracing
 * @returns {string} Unique request ID
 */
export function generateRequestId() {
  return `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}
