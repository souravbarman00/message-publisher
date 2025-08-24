# Message Publisher Development Setup Script for PowerShell
# This script helps you set up and run the message publisher system

param(
    [string]$Command = "setup"
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Yellow
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

function Test-Command {
    param([string]$CommandName)
    try {
        Get-Command $CommandName -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Test-Port {
    param([int]$Port)
    try {
        $connection = New-Object System.Net.Sockets.TcpClient
        $connection.Connect("localhost", $Port)
        $connection.Close()
        return $true
    }
    catch {
        return $false
    }
}

function Check-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    if (-not (Test-Command "node")) {
        Write-Error-Message "Node.js is not installed. Please install Node.js 18+ first."
        exit 1
    }
    
    $nodeVersion = node -v
    $versionNumber = [int]($nodeVersion -replace "v(\d+)\..*", '$1')
    if ($versionNumber -lt 18) {
        Write-Error-Message "Node.js version 18+ is required. Current version: $nodeVersion"
        exit 1
    }
    
    if (-not (Test-Command "npm")) {
        Write-Error-Message "npm is not installed."
        exit 1
    }
    
    Write-Success "Prerequisites check passed"
}

function Check-Kafka {
    Write-Status "Checking Kafka connectivity..."
    
    if (Test-Port 9092) {
        Write-Success "Kafka is running on localhost:9092"
    } else {
        Write-Warning "Kafka is not running on localhost:9092"
        Write-Warning "Please start Kafka before running the workers"
    }
}

function Install-Dependencies {
    Write-Status "Installing dependencies..."
    
    # Root dependencies
    if (Test-Path "package.json") {
        npm install
        if ($LASTEXITCODE -ne 0) {
            Write-Error-Message "Failed to install root dependencies"
            exit 1
        }
    }
    
    # API dependencies
    if ((Test-Path "api") -and (Test-Path "api\package.json")) {
        Write-Status "Installing API dependencies..."
        Push-Location api
        npm install
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-Error-Message "Failed to install API dependencies"
            exit 1
        }
        Pop-Location
    }
    
    # Workers dependencies
    if ((Test-Path "workers") -and (Test-Path "workers\package.json")) {
        Write-Status "Installing Workers dependencies..."
        Push-Location workers
        npm install
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-Error-Message "Failed to install Workers dependencies"
            exit 1
        }
        Pop-Location
    }
    
    # Frontend dependencies
    if ((Test-Path "frontend") -and (Test-Path "frontend\package.json")) {
        Write-Status "Installing Frontend dependencies..."
        Push-Location frontend
        npm install
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-Error-Message "Failed to install Frontend dependencies"
            exit 1
        }
        Pop-Location
    }
    
    Write-Success "Dependencies installed successfully"
}

function Setup-Environment {
    Write-Status "Setting up environment files..."
    
    # Check if .env files exist, if not, provide guidance
    if (-not (Test-Path "api\.env")) {
        Write-Status "Creating API .env file template..."
        $apiEnvContent = @"
# API Configuration
PORT=4000

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here

# SNS Configuration
SNS_TOPIC_ARN=arn:aws:sns:us-east-1:123456789012:your-topic-name

# SQS Configuration
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123456789012/your-queue-name

# Kafka Configuration
KAFKA_BROKERS=localhost:9092
KAFKA_TOPIC=messages
"@
        Set-Content -Path "api\.env" -Value $apiEnvContent
        Write-Warning "Created api\.env - Please update with your actual AWS credentials"
    }
    
    if (-not (Test-Path "workers\.env")) {
        Write-Status "Creating Workers .env file template..."
        $workersEnvContent = @"
# Worker Configuration
NODE_ENV=development

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here

# SNS Configuration
SNS_TOPIC_ARN=arn:aws:sns:us-east-1:123456789012:your-topic-name

# SQS Configuration
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123456789012/your-queue-name

# Kafka Configuration
KAFKA_BROKERS=localhost:9092
KAFKA_TOPIC=messages
KAFKA_CONSUMER_GROUP=message-publisher-workers

# Worker Configuration
KAFKA_POLL_INTERVAL=1000
SQS_POLL_INTERVAL=5000
SNS_POLL_INTERVAL=10000
"@
        Set-Content -Path "workers\.env" -Value $workersEnvContent
        Write-Warning "Created workers\.env - Please update with your actual AWS credentials"
    }
    
    Write-Success "Environment files setup completed"
}

function Check-Ports {
    Write-Status "Checking port availability..."
    
    if (Test-Port 3000) {
        Write-Warning "Port 3000 is in use (Frontend)"
    }
    
    if (Test-Port 4000) {
        Write-Warning "Port 4000 is in use (API)"
    }
}

function Start-Services {
    param([string]$ServiceType)
    
    Write-Status "Starting services..."
    
    switch ($ServiceType) {
        "api" {
            Write-Status "Starting API service..."
            Push-Location api
            npm run dev
            Pop-Location
        }
        "workers" {
            Write-Status "Starting Worker services..."
            Push-Location workers
            npm run dev:all
            Pop-Location
        }
        "frontend" {
            Write-Status "Starting Frontend..."
            Push-Location frontend
            npm start
            Pop-Location
        }
        "all" {
            Write-Status "Starting all services..."
            Write-Status "Opening new PowerShell windows for each service..."
            
            $currentDir = Get-Location
            
            # Start API
            Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$currentDir\api'; npm run dev"
            Start-Sleep 2
            
            # Start Workers  
            Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$currentDir\workers'; npm run dev:all"
            Start-Sleep 2
            
            # Start Frontend
            Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$currentDir\frontend'; npm start"
            
            Write-Success "All services started in separate windows"
            Write-Status "Frontend: http://localhost:3000"
            Write-Status "API: http://localhost:4000"
            Write-Status "API Docs: http://localhost:4000/api/docs"
        }
        default {
            Write-Error-Message "Unknown service: $ServiceType"
            Write-Error-Message "Available options: api, workers, frontend, all"
            exit 1
        }
    }
}

function Show-Help {
    Write-Host "Message Publisher Development Setup" -ForegroundColor $Blue
    Write-Host ""
    Write-Host "Usage: .\setup.ps1 [COMMAND]" -ForegroundColor $Yellow
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor $Green
    Write-Host "  setup          - Install dependencies and setup environment"
    Write-Host "  start          - Start all services"
    Write-Host "  start-api      - Start API service only"
    Write-Host "  start-workers  - Start worker services only"  
    Write-Host "  start-frontend - Start frontend only"
    Write-Host "  check          - Check system prerequisites"
    Write-Host "  help           - Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor $Yellow
    Write-Host "  .\setup.ps1 setup              # Initial setup"
    Write-Host "  .\setup.ps1 start              # Start all services"
    Write-Host "  .\setup.ps1 start-api          # Start API only"
    Write-Host ""
}

# Main script logic
switch ($Command.ToLower()) {
    "setup" {
        Check-Prerequisites
        Check-Kafka
        Install-Dependencies
        Setup-Environment
        Check-Ports
        Write-Success "Setup completed!"
        Write-Status "Run '.\setup.ps1 start' to start all services"
    }
    "start" {
        Start-Services "all"
    }
    "start-api" {
        Start-Services "api"
    }
    "start-workers" {
        Start-Services "workers"
    }
    "start-frontend" {
        Start-Services "frontend"
    }
    "check" {
        Check-Prerequisites
        Check-Kafka
        Check-Ports
    }
    { $_ -in @("help", "-h", "--help") } {
        Show-Help
    }
    default {
        Write-Error-Message "Unknown command: $Command"
        Show-Help
        exit 1
    }
}
