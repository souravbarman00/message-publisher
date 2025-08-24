import { MESSAGE_TYPES } from '../constants/messageTypes.js';

/**
 * Validate message payload
 * @param {Object} payload - Message payload to validate
 * @returns {Object} Validation result
 */
export function validateMessage(payload) {
  const errors = [];
  
  if (!payload) {
    errors.push('Payload is required');
    return { isValid: false, errors };
  }
  
  if (!payload.message || typeof payload.message !== 'string' || payload.message.trim().length === 0) {
    errors.push('Message is required and must be a non-empty string');
  }
  
  if (payload.metadata && typeof payload.metadata !== 'object') {
    errors.push('Metadata must be an object');
  }
  
  if (payload.type && !Object.values(MESSAGE_TYPES).includes(payload.type)) {
    errors.push('Invalid message type');
  }
  
  return {
    isValid: errors.length === 0,
    errors
  };
}

/**
 * Validate JSON string
 * @param {string} jsonString - JSON string to validate
 * @returns {Object} Validation result with parsed data
 */
export function validateJSON(jsonString) {
  if (!jsonString || jsonString.trim().length === 0) {
    return { isValid: true, data: {} };
  }
  
  try {
    const parsed = JSON.parse(jsonString);
    return { isValid: true, data: parsed };
  } catch (error) {
    return { 
      isValid: false, 
      error: 'Invalid JSON format',
      details: error.message 
    };
  }
}

/**
 * Sanitize message content
 * @param {string} message - Message to sanitize
 * @returns {string} Sanitized message
 */
export function sanitizeMessage(message) {
  if (typeof message !== 'string') {
    return '';
  }
  
  return message
    .trim()
    .replace(/[\r\n\t]/g, ' ')
    .replace(/\s+/g, ' ')
    .substring(0, 10000); // Max 10k characters
}
