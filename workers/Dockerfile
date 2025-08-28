# Multi-stage Dockerfile for Message Publisher Workers Service

# Stage 1: Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --only=production && npm cache clean --force

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
ENV LOG_LEVEL=info

# Health check script
RUN echo '#!/bin/sh' > /usr/local/bin/health-check.sh && \
    echo 'pgrep -f "node.*worker" > /dev/null || exit 1' >> /usr/local/bin/health-check.sh && \
    chmod +x /usr/local/bin/health-check.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /usr/local/bin/health-check.sh || exit 1

# Switch to non-root user
USER nodejs

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start all worker services
CMD ["npm", "run", "start:all"]

# Build metadata
LABEL maintainer="Message Publisher Team"
LABEL version="1.0.0"
LABEL description="Message Publisher Workers - Background services for processing Kafka, SNS, and SQS messages"
LABEL build-date=${BUILD_DATE}
LABEL vcs-url="https://github.com/your-org/message-publisher"
LABEL vcs-ref=${VCS_REF}
