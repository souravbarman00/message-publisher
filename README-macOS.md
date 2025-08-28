# 🍎 macOS Setup Guide for Message Publisher

This guide provides macOS-specific instructions for setting up and running the Message Publisher system.

## 🚀 Quick Start for macOS

### Option 1: One-Click Setup (Recommended)
```bash
# Make scripts executable
chmod +x setup-mac.sh launch-mac.sh

# Run the interactive launcher
./launch-mac.sh
```

### Option 2: Command Line Setup
```bash
# Make the script executable
chmod +x setup-mac.sh

# Run complete setup
./setup-mac.sh setup

# Start all services
./setup-mac.sh start
```

## 🔧 macOS-Specific Features

### 1. **Homebrew Integration**
The macOS script automatically detects and uses Homebrew for system dependencies:
- Installs Node.js if missing
- Manages Kafka installation
- Handles development tools via Brewfile

### 2. **Native Terminal Management**
- Opens services in separate Terminal tabs
- Uses AppleScript for native macOS integration
- Automatic window management

### 3. **Automatic Browser Launch**
- Opens the frontend at `http://localhost:3000`
- Opens API health check automatically
- Uses macOS `open` command

### 4. **System Integration**
- Checks for Xcode Command Line Tools
- Validates macOS version compatibility
- Integrates with macOS notifications

## 📋 Prerequisites

### Automatic Installation
The script will automatically install missing prerequisites:

1. **Xcode Command Line Tools** (automatically prompted)
2. **Homebrew** (optional, but recommended)
3. **Node.js 18+** (via Homebrew if available)

### Manual Installation
If you prefer manual setup:

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Node.js
brew install node

# Install Kafka (optional, for local development)
brew install kafka
brew services start kafka
```

## 🛠 Available Commands

```bash
./setup-mac.sh setup          # Complete project setup
./setup-mac.sh start          # Start all services in Terminal tabs
./setup-mac.sh start-api      # Start API service only
./setup-mac.sh start-workers  # Start worker services only
./setup-mac.sh start-frontend # Start frontend only
./setup-mac.sh check          # Check system prerequisites
./setup-mac.sh info           # Show system information
./setup-mac.sh clean          # Clean and reinstall dependencies
./setup-mac.sh open           # Open project URLs in browser
./setup-mac.sh help           # Show help
```

## 🎯 Services & Ports

After running `./setup-mac.sh start`, the following services will be available:

- **Frontend**: http://localhost:3000 🎨
- **API**: http://localhost:4000 ⚙️
- **Health Check**: http://localhost:4000/api/health ❤️
- **API Docs**: http://localhost:4000/api/docs 📚

## 🔄 Development Workflow

### First Time Setup
```bash
# 1. Clone or download the project
cd /path/to/message-publisher

# 2. Make scripts executable
chmod +x setup-mac.sh launch-mac.sh

# 3. Run setup
./setup-mac.sh setup

# 4. Configure environment files (will be prompted)
code api/.env workers/.env  # or use any editor
```

### Daily Development
```bash
# Start everything
./setup-mac.sh start

# Or use the launcher
./launch-mac.sh
```

## 🐛 Troubleshooting

### Common macOS Issues

**Permission Denied**
```bash
chmod +x setup-mac.sh launch-mac.sh
```

**Xcode Command Line Tools Missing**
```bash
xcode-select --install
```

**Port Already in Use**
```bash
# Kill process on port 3000 or 4000
lsof -ti:3000 | xargs kill -9
lsof -ti:4000 | xargs kill -9
```

**Homebrew Not Found**
```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH (for Apple Silicon Macs)
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Node.js Version Too Old**
```bash
# Update Node.js via Homebrew
brew upgrade node

# Or use Node Version Manager
brew install nvm
nvm install 18
nvm use 18
```

## 🎨 IDE Integration

### VS Code Setup
The script can automatically open VS Code if installed:
```bash
# Install VS Code via Homebrew
brew install --cask visual-studio-code

# Open project in VS Code
code .
```

### Recommended VS Code Extensions
- ES7+ React/Redux/React-Native snippets
- Prettier - Code formatter
- ESLint
- Thunder Client (for API testing)
- GitLens

## 🔐 Environment Configuration

### API Configuration (`api/.env`)
```env
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here

# SNS Configuration
SNS_TOPIC_ARN=arn:aws:sns:us-east-1:123456789012:your-topic

# SQS Configuration
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123456789012/your-queue

# Kafka Configuration (for local Kafka via Homebrew)
KAFKA_BROKERS=localhost:9092
KAFKA_TOPIC=messages
```

### Workers Configuration (`workers/.env`)
```env
# Same as API configuration
# Workers need access to the same services
```

## 🚀 Performance Tips for macOS

### 1. **Use Terminal Tabs Instead of Windows**
The script automatically creates Terminal tabs which is more efficient than separate windows.

### 2. **Enable Hot Reloading**
Development servers automatically reload on file changes - no need to restart manually.

### 3. **Use Activity Monitor**
Monitor resource usage:
- Open Activity Monitor
- Check CPU and Memory usage for Node.js processes

### 4. **Optimize for Apple Silicon**
If you're on an M1/M2 Mac, ensure you're using native ARM64 versions of Node.js and other tools.

## 📱 Mobile Development

The React frontend is responsive and works well on mobile browsers:

```bash
# Get your local IP address
ifconfig | grep "inet " | grep -v 127.0.0.1

# Access from mobile device
# http://YOUR_IP_ADDRESS:3000
```

## 🎉 Success! 

Once everything is running, you should see:
- ✅ Three Terminal tabs with running services
- 🌐 Browser windows opening automatically
- 🎨 Frontend available at localhost:3000
- ⚙️ API responding at localhost:4000

## 📞 Support

If you encounter any macOS-specific issues:
1. Check the Terminal output for detailed error messages
2. Run `./setup-mac.sh check` to diagnose system issues
3. Ensure Xcode Command Line Tools are installed
4. Verify Homebrew is working correctly

## 🔄 Keeping Updated

To update your development environment:
```bash
# Update Homebrew packages
brew update && brew upgrade

# Clean and reinstall project dependencies
./setup-mac.sh clean
./setup-mac.sh setup
```

---

**🍎 Enjoy developing on macOS!** This setup provides a smooth, native development experience optimized for Mac users.