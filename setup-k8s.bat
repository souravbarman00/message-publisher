@echo off
setlocal enabledelayedexpansion

:: Kubernetes and ArgoCD Setup Script for Windows
:: Fully automated setup with zero manual intervention required

set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

echo %BLUE%=======================================%NC%
echo %BLUE%  Kubernetes + ArgoCD Setup (Windows)  %NC%
echo %BLUE%=======================================%NC%
echo.

:: Function definitions
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

:command_exists
where %1 >nul 2>&1
exit /b %errorlevel%

:wait_for_condition
set max_attempts=60
set attempt=0
:wait_loop
%~1 >nul 2>&1
if !errorlevel! equ 0 goto :eof
set /a attempt+=1
if !attempt! geq !max_attempts! (
    call :print_error "Timeout waiting for condition: %~2"
    exit /b 1
)
timeout /t 5 >nul
goto wait_loop

:: Step 1: Install Prerequisites
:install_prerequisites
call :print_status "Installing prerequisites..."

:: Check if Chocolatey is installed
call :command_exists choco
if !errorlevel! neq 0 (
    call :print_status "Installing Chocolatey package manager..."
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
    refreshenv
)

:: Install kubectl
call :command_exists kubectl
if !errorlevel! neq 0 (
    call :print_status "Installing kubectl..."
    choco install kubernetes-cli -y
    refreshenv
)

:: Install kind
call :command_exists kind
if !errorlevel! neq 0 (
    call :print_status "Installing kind (Kubernetes in Docker)..."
    choco install kind -y
    refreshenv
)

:: Check Docker
call :command_exists docker
if !errorlevel! neq 0 (
    call :print_error "Docker is required but not installed. Please install Docker Desktop first."
    exit /b 1
)

call :print_success "Prerequisites installed successfully"
goto :eof

:: Step 2: Create Kubernetes Cluster
:create_cluster
call :print_status "Setting up Kubernetes cluster..."

:: Check if cluster already exists
kind get clusters | findstr message-publisher >nul 2>&1
if !errorlevel! equ 0 (
    call :print_warning "Cluster 'message-publisher' already exists. Deleting and recreating..."
    kind delete cluster --name message-publisher
)

call :print_status "Creating kind cluster with custom configuration..."
kind create cluster --name message-publisher --config kind-config.yaml
if !errorlevel! neq 0 (
    call :print_error "Failed to create Kubernetes cluster"
    exit /b 1
)

call :print_status "Setting kubectl context..."
kubectl config use-context kind-message-publisher

call :print_status "Waiting for cluster to be ready..."
call :wait_for_condition "kubectl get nodes --no-headers | findstr Ready" "cluster readiness"

call :print_success "Kubernetes cluster created successfully"
goto :eof

:: Step 3: Install Ingress Controller
:install_ingress
call :print_status "Installing NGINX Ingress Controller..."

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

call :print_status "Waiting for ingress controller to be ready..."
call :wait_for_condition "kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers | findstr Running" "ingress controller"

call :print_success "Ingress controller installed successfully"
goto :eof

:: Step 4: Install ArgoCD
:install_argocd
call :print_status "Installing ArgoCD..."

kubectl create namespace argocd 2>nul
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

call :print_status "Waiting for ArgoCD to be ready (this may take a few minutes)..."
call :wait_for_condition "kubectl get deployment argocd-server -n argocd --no-headers | findstr -E \"1/1|2/2|3/3\"" "ArgoCD server deployment"

call :print_success "ArgoCD installed successfully"
goto :eof

:: Step 5: Get ArgoCD Password and Setup Access
:setup_argocd_access
call :print_status "Setting up ArgoCD access..."

:: Get admin password
for /f "delims=" %%i in ('kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath^="{.data.password}"') do set encoded_password=%%i
for /f "delims=" %%i in ('powershell -command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('%encoded_password%'))"') do set admin_password=%%i

:: Create ArgoCD access script
echo @echo off > access-argocd.bat
echo echo Starting ArgoCD port forward... >> access-argocd.bat
echo echo ArgoCD will be available at: https://localhost:8090 >> access-argocd.bat
echo echo Username: admin >> access-argocd.bat
echo echo Password: %admin_password% >> access-argocd.bat
echo echo. >> access-argocd.bat
echo echo Press Ctrl+C to stop port forwarding >> access-argocd.bat
echo kubectl port-forward svc/argocd-server -n argocd 8090:443 >> access-argocd.bat

call :print_success "ArgoCD access script created: access-argocd.bat"
call :print_status "ArgoCD Credentials:"
echo   URL: https://localhost:8090
echo   Username: admin
echo   Password: %admin_password%
goto :eof

:: Step 6: Deploy Applications
:deploy_applications
call :print_status "Deploying applications to Kubernetes..."

:: Create application namespace
kubectl create namespace message-publisher 2>nul

:: Build and load Docker images
call :print_status "Building Docker images..."
docker build -t message-publisher-api:latest ./api
docker build -t message-publisher-workers:latest ./workers
docker build -t message-publisher-frontend:latest ./frontend

call :print_status "Loading images into kind cluster..."
kind load docker-image message-publisher-api:latest --name message-publisher
kind load docker-image message-publisher-workers:latest --name message-publisher
kind load docker-image message-publisher-frontend:latest --name message-publisher

:: Apply Kubernetes manifests
call :print_status "Applying Kubernetes manifests..."
kubectl apply -f k8s/api-deployment.yaml -n message-publisher
kubectl apply -f k8s/workers-deployment.yaml -n message-publisher
kubectl apply -f k8s/frontend-deployment.yaml -n message-publisher

:: Wait for deployments to be ready
call :print_status "Waiting for deployments to be ready..."
kubectl rollout status deployment/message-publisher-api -n message-publisher --timeout=300s
kubectl rollout status deployment/message-publisher-workers -n message-publisher --timeout=300s
kubectl rollout status deployment/message-publisher-frontend -n message-publisher --timeout=300s

call :print_success "Applications deployed successfully"
goto :eof

:: Step 7: Setup ArgoCD Application
:setup_argocd_app
call :print_status "Setting up ArgoCD application..."

:: Apply ArgoCD application manifest
kubectl apply -f k8s/argocd-application.yaml

call :print_success "ArgoCD application configured"
goto :eof

:: Step 8: Create Access Scripts
:create_access_scripts
call :print_status "Creating application access scripts..."

:: Frontend access script
echo @echo off > access-frontend.bat
echo echo Starting frontend port forward... >> access-frontend.bat
echo echo Frontend available at: http://localhost:3000 >> access-frontend.bat
echo echo Press Ctrl+C to stop >> access-frontend.bat
echo kubectl port-forward svc/message-publisher-frontend-service -n message-publisher 3000:80 >> access-frontend.bat

:: API access script
echo @echo off > access-api.bat
echo echo Starting API port forward... >> access-api.bat
echo echo API available at: http://localhost:4000 >> access-api.bat
echo echo Press Ctrl+C to stop >> access-api.bat
echo kubectl port-forward svc/message-publisher-api-service -n message-publisher 4000:80 >> access-api.bat

:: Combined status script
echo @echo off > k8s-status.bat
echo echo Kubernetes Cluster Status: >> k8s-status.bat
echo kubectl get nodes >> k8s-status.bat
echo echo. >> k8s-status.bat
echo echo Application Status: >> k8s-status.bat
echo kubectl get pods -n message-publisher >> k8s-status.bat
echo echo. >> k8s-status.bat
echo echo Services: >> k8s-status.bat
echo kubectl get services -n message-publisher >> k8s-status.bat
echo echo. >> k8s-status.bat
echo echo ArgoCD Status: >> k8s-status.bat
echo kubectl get pods -n argocd >> k8s-status.bat

call :print_success "Access scripts created:"
echo   - access-argocd.bat   : Access ArgoCD UI
echo   - access-frontend.bat : Access Frontend
echo   - access-api.bat      : Access API
echo   - k8s-status.bat      : Check cluster status
goto :eof

:: Step 9: Final Setup
:final_setup
call :print_status "Completing setup..."

:: Create cleanup script
echo @echo off > cleanup-k8s.bat
echo echo Cleaning up Kubernetes resources... >> cleanup-k8s.bat
echo kind delete cluster --name message-publisher >> cleanup-k8s.bat
echo del access-*.bat k8s-status.bat cleanup-k8s.bat 2^>nul >> cleanup-k8s.bat
echo echo Cleanup completed >> cleanup-k8s.bat

call :print_success "Setup completed successfully!"
echo.
echo %GREEN%=======================================%NC%
echo %GREEN%        Setup Complete!               %NC%
echo %GREEN%=======================================%NC%
echo.
echo Next steps:
echo 1. Run: access-argocd.bat     (ArgoCD UI at https://localhost:8090)
echo 2. Run: access-frontend.bat   (Frontend at http://localhost:3000)
echo 3. Run: access-api.bat        (API at http://localhost:4000)
echo 4. Run: k8s-status.bat        (Check cluster status)
echo.
echo Ports used:
echo - Kafka UI:     8080 (existing)
echo - ArgoCD:       8090
echo - Frontend:     3000
echo - API:          4000
echo.
echo To cleanup everything: cleanup-k8s.bat
goto :eof

:: Main execution
call :print_status "Starting Kubernetes and ArgoCD setup..."

call :install_prerequisites
if !errorlevel! neq 0 exit /b 1

call :create_cluster
if !errorlevel! neq 0 exit /b 1

call :install_ingress
if !errorlevel! neq 0 exit /b 1

call :install_argocd
if !errorlevel! neq 0 exit /b 1

call :setup_argocd_access
if !errorlevel! neq 0 exit /b 1

call :deploy_applications
if !errorlevel! neq 0 exit /b 1

call :setup_argocd_app
if !errorlevel! neq 0 exit /b 1

call :create_access_scripts
if !errorlevel! neq 0 exit /b 1

call :final_setup

endlocal
