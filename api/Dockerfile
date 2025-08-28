# Multi-stage Dockerfile for Message Publisher API Service

# Stage 1: Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Stage 2: Production stage
FROM node:18-alpine AS production

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Copy dependencies from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application source
COPY --chown=nodejs:nodejs . .

# Create logs directory
RUN mkdir -p logs && chown nodejs:nodejs logs

# Set environment variables
ENV NODE_ENV=production
ENV PORT=4000
ENV LOG_LEVEL=info

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node healthcheck.js || exit 1

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 4000

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "server.js"]

# Build metadata
LABEL maintainer="Message Publisher Team"
LABEL version="1.0.0"
LABEL description="Message Publisher API Service - Express.js application for publishing messages to Kafka, SNS, and SQS"
LABEL build-date=${BUILD_DATE}
LABEL vcs-url="https://github.com/your-org/message-publisher"
LABEL vcs-ref=${VCS_REF}