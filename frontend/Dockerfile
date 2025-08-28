# Multi-stage build for React app
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies for building)
RUN npm install

# Copy source code
COPY . .

# Build the React app
RUN npm run build

# Production stage - serve with nginx
FROM nginx:alpine

# Copy built React app from builder stage
COPY --from=builder /app/build /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Build metadata
LABEL maintainer="Message Publisher Team"
LABEL version="1.0.0"
LABEL description="Message Publisher Frontend - React application for message publishing interface"
LABEL build-date=${BUILD_DATE}
LABEL vcs-url="https://github.com/your-org/message-publisher"
LABEL vcs-ref=${VCS_REF}

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
