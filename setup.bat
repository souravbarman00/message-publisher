@echo off
setlocal enabledelayedexpansion

:: Message Publisher Development Setup Script for Windows
:: This script helps you set up and run the message publisher system

set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

:: Function to print colored output
:print_status
echo %BLUE%[INFO]%NC% %~1
goto :eof

:print_success
echo %GREEN%[SUCCESS]%NC% %~1
goto :eof

:print_warning
echo %YELLOW%[WARNING]%NC% %~1
goto :eof

:print_error
echo %RED%[ERROR]%NC% %~1
goto :eof

:: Check if command exists
:command_exists
where %1 >nul 2>&1
if %errorlevel% equ 0 (
    exit /b 0
) else (
    exit /b 1
)

:: Check prerequisites
:check_prerequisites
call :print_status "Checking prerequisites..."

call :command_exists node
if !errorlevel! neq 0 (
    call :print_error "Node.js is not installed. Please install Node.js 18+ first."
    exit /b 1
)

call :command_exists npm
if !errorlevel! neq 0 (
    call :print_error "npm is not installed."
    exit /b 1
)

call :print_success "Prerequisites check passed"
goto :eof

:: Install dependencies
:install_dependencies
call :print_status "Installing dependencies..."

if exist "package.json" (
    npm install
)

if exist "api\package.json" (
    call :print_status "Installing API dependencies..."
    cd api
    npm install
    cd ..
)

if exist "workers\package.json" (
    call :print_status "Installing Workers dependencies..."
    cd workers
    npm install
    cd ..
)

if exist "frontend\package.json" (
    call :print_status "Installing Frontend dependencies..."
    cd frontend
    npm install
    cd ..
)

call :print_success "Dependencies installed successfully"
goto :eof

:: Setup environment files
:setup_env
call :print_status "Setting up environment files..."

if not exist "api\.env" (
    if exist "api\.env" (
        call :print_status "Creating API .env file..."
        copy "api\.env" "api\.env"
        call :print_warning "Please update api\.env with your AWS credentials and service URLs"
    )
)

if not exist "workers\.env" (
    if exist "workers\.env" (
        call :print_status "Creating Workers .env file..."
        copy "workers\.env" "workers\.env"
        call :print_warning "Please update workers\.env with your AWS credentials and service URLs"
    )
)

if not exist "api\.env" (
    call :print_warning "Environment files need to be configured with your AWS credentials"
    call :print_warning "Update the following files:"
    call :print_warning "  - api\.env"
    call :print_warning "  - workers\.env"
)
goto :eof

:: Start services
:start_services
set service=%~1
call :print_status "Starting services..."

if "%service%"=="api" (
    call :print_status "Starting API service..."
    cd api
    npm run dev
    cd ..
) else if "%service%"=="workers" (
    call :print_status "Starting Worker services..."
    cd workers
    npm run dev:all
    cd ..
) else if "%service%"=="frontend" (
    call :print_status "Starting Frontend..."
    cd frontend
    npm start
    cd ..
) else if "%service%"=="all" (
    call :print_status "Starting all services..."
    call :print_status "Opening new command windows for each service..."
    
    start "API Service" cmd /k "cd /d %CD%\api && npm run dev"
    timeout /t 2 >nul
    start "Worker Services" cmd /k "cd /d %CD%\workers && npm run dev:all"
    timeout /t 2 >nul
    start "Frontend" cmd /k "cd /d %CD%\frontend && npm start"
    
    call :print_success "All services started in separate windows"
) else (
    call :print_error "Unknown service: %service%"
    call :print_error "Available options: api, workers, frontend, all"
    exit /b 1
)
goto :eof

:: Show help
:show_help
echo Message Publisher Development Setup
echo.
echo Usage: %0 [COMMAND]
echo.
echo Commands:
echo   setup          - Install dependencies and setup environment
echo   start          - Start all services
echo   start-api      - Start API service only
echo   start-workers  - Start worker services only
echo   start-frontend - Start frontend only
echo   check          - Check system prerequisites
echo   help           - Show this help message
echo.
echo Examples:
echo   %0 setup              # Initial setup
echo   %0 start              # Start all services
echo   %0 start-api          # Start API only
echo.
goto :eof

:: Main script logic
if "%~1"=="" set "cmd=setup"
if not "%~1"=="" set "cmd=%~1"

if "%cmd%"=="setup" (
    call :check_prerequisites
    if !errorlevel! neq 0 exit /b 1
    call :install_dependencies
    call :setup_env
    call :print_success "Setup completed!"
    call :print_status "Run '%0 start' to start all services"
) else if "%cmd%"=="start" (
    call :start_services "all"
) else if "%cmd%"=="start-api" (
    call :start_services "api"
) else if "%cmd%"=="start-workers" (
    call :start_services "workers"
) else if "%cmd%"=="start-frontend" (
    call :start_services "frontend"
) else if "%cmd%"=="check" (
    call :check_prerequisites
) else if "%cmd%"=="help" (
    call :show_help
) else if "%cmd%"=="-h" (
    call :show_help
) else if "%cmd%"=="--help" (
    call :show_help
) else (
    call :print_error "Unknown command: %cmd%"
    call :show_help
    exit /b 1
)

endlocal
