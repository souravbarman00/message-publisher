@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM                MESSAGE PUBLISHER - WINDOWS SETUP
REM =============================================================================
REM Interactive setup script with menu options
REM =============================================================================

:MAIN_MENU
cls
echo.
echo ================================================================
echo            MESSAGE PUBLISHER - WINDOWS SETUP
echo ================================================================
echo.
echo What would you like to do?
echo.
echo 1. Install Development Tools (Java, Node.js, Docker, kubectl, Kind)
echo 2. Start Docker Desktop
echo 3. Create Kind Kubernetes Cluster
echo 4. Install ArgoCD
echo 5. Apply Secrets ^& ConfigMap
echo 6. Start Port Forwarding (Frontend ^& ArgoCD)
echo 7. Full Setup (All above steps)
echo 8. Exit
echo.
set /p choice="Enter your choice (1-8): "

if "%choice%"=="1" goto :INSTALL_TOOLS
if "%choice%"=="2" goto :START_DOCKER
if "%choice%"=="3" goto :CREATE_CLUSTER
if "%choice%"=="4" goto :INSTALL_ARGOCD
if "%choice%"=="5" goto :APPLY_SECRETS
if "%choice%"=="6" goto :PORT_FORWARD
if "%choice%"=="7" goto :FULL_SETUP
if "%choice%"=="8" goto :EXIT
echo Invalid choice. Please select 1-8.
pause
goto :MAIN_MENU

:INSTALL_TOOLS
echo.
echo [INFO] Installing development tools...
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This option requires Administrator privileges
    echo Right-click on the script and select "Run as administrator"
    pause
    goto :MAIN_MENU
)

REM Install Chocolatey if not present
where choco >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing Chocolatey package manager...
    powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    call refreshenv
) else (
    echo Chocolatey already installed
)

REM Check and install Java 21 if not present
java -version 2>nul | findstr "21\." >nul
if %errorLevel% neq 0 (
    echo Installing Java 21...
    choco install openjdk21 -y
) else (
    echo Java 21 already installed
)

REM Check and install Node.js 18 if not present
where node >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing Node.js 18...
    choco install nodejs --version=18.20.4 -y
) else (
    echo Node.js already installed
)

REM Check and install Git if not present
where git >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing Git...
    choco install git -y
) else (
    echo Git already installed
)

REM Check and install kubectl if not present
where kubectl >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing kubectl...
    choco install kubernetes-cli -y
) else (
    echo kubectl already installed
)

REM Check and install Kind if not present
where kind >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing Kind...
    choco install kind -y
) else (
    echo Kind already installed
)

REM Check and install Docker Desktop if not present
where docker >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing Docker Desktop...
    choco install docker-desktop -y
) else (
    echo Docker already installed
)

REM Refresh environment variables
call refreshenv

echo.
echo [SUCCESS] Development tools installation completed!
echo.
pause
goto :MAIN_MENU

:START_DOCKER
echo.
echo [INFO] Checking Docker Desktop status...
echo.

docker ps >nul 2>&1
if %errorLevel% equ 0 (
    echo [SUCCESS] Docker Desktop is already running!
) else (
    echo [WARNING] Docker Desktop is not running.
    echo Please start Docker Desktop manually:
    echo 1. Open Docker Desktop from Start Menu
    echo 2. Wait for Docker to fully start
    echo.
    pause
    
    REM Verify Docker is running
    docker ps >nul 2>&1
    if %errorLevel% equ 0 (
        echo [SUCCESS] Docker Desktop is now running!
    ) else (
        echo [ERROR] Docker Desktop is still not running. Please check and try again.
    )
)

echo.
pause
goto :MAIN_MENU

:CREATE_CLUSTER
echo.
echo [INFO] Creating Kind Kubernetes cluster...
echo.

REM Check if cluster already exists
kind get clusters 2>nul | findstr "message-publisher" >nul
if %errorLevel% equ 0 (
    echo [WARNING] Kind cluster 'message-publisher' already exists.
    set /p recreate="Do you want to recreate it? (y/N): "
    if /I "!recreate!"=="y" (
        echo [INFO] Deleting existing cluster...
        kind delete cluster --name message-publisher
    ) else (
        echo [SUCCESS] Using existing cluster.
        call :JENKINS_SETUP
        goto :MAIN_MENU
    )
)

REM Create cluster
echo [INFO] Creating cluster 'message-publisher'...
kind create cluster --name=message-publisher

if %errorLevel% equ 0 (
    echo [SUCCESS] Kind cluster created successfully!
    
    REM Verify cluster
    kubectl cluster-info --context kind-message-publisher
    kubectl get nodes
    
    echo.
    call :JENKINS_SETUP
) else (
    echo [ERROR] Failed to create Kind cluster
    echo Make sure Docker Desktop is running and try again
    echo.
    pause
)
goto :MAIN_MENU

:JENKINS_SETUP
echo.
echo [INFO] Jenkins Integration Setup Required
echo.
echo ================================================================
echo                 JENKINS SETUP INSTRUCTIONS
echo ================================================================
echo.
echo To complete Jenkins integration, you need to:
echo.
echo 1. CREATE JENKINS NODE:
echo    - Go to Jenkins: Manage Jenkins - Nodes
echo    - Click 'New Node'
echo    - Name: %COMPUTERNAME%-local-k8s
echo    - Type: Permanent Agent
echo    - Configure with your local machine details
echo.
echo 2. UPLOAD KUBECONFIG CREDENTIAL:
echo    - Go to Jenkins: Manage Jenkins - Credentials
echo    - Add new 'Secret file' credential
echo    - Upload file: %USERPROFILE%\.kube\config
echo    - ID: kubeconfig-kind-%COMPUTERNAME%-local-k8s
echo    - Description: 'Kind cluster kubeconfig for %COMPUTERNAME%'
echo.
echo 3. KUBECONFIG FILE LOCATION:
echo    File to upload: %USERPROFILE%\.kube\config
for /f "tokens=*" %%i in ('kubectl config current-context 2^>nul') do set CURRENT_CONTEXT=%%i
echo    Current cluster: !CURRENT_CONTEXT!
echo.
echo 4. VERIFY CREDENTIAL:
echo    - Test the credential in Jenkins
echo    - Run a test pipeline to ensure connectivity
echo.
echo ================================================================
echo.

set /p open_config="Do you want to open the kubeconfig file location? (y/N): "
if /I "!open_config!"=="y" (
    echo [INFO] Opening kubeconfig directory...
    explorer %USERPROFILE%\.kube\
)

echo.
set /p jenkins_done="Have you completed the Jenkins setup? (y/N): "
if /I "!jenkins_done!"=="y" (
    echo [SUCCESS] Jenkins integration setup completed!
) else (
    echo [WARNING] Please complete Jenkins setup before running builds.
    echo [INFO] You can return to this menu option later.
)

echo.
pause
return

:INSTALL_ARGOCD
echo.
echo [INFO] Installing ArgoCD...
echo.

REM Check if ArgoCD is already installed
kubectl get namespace argocd >nul 2>&1
if %errorLevel% equ 0 (
    echo [WARNING] ArgoCD namespace already exists.
    set /p reinstall="Do you want to reinstall ArgoCD? (y/N): "
    if /I NOT "!reinstall!"=="y" (
        echo [SUCCESS] Using existing ArgoCD installation.
        pause
        goto :MAIN_MENU
    )
)

REM Create namespace and install ArgoCD
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo [INFO] Waiting for ArgoCD to be ready...
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

if %errorLevel% equ 0 (
    REM Get ArgoCD admin password
    for /f "tokens=*" %%i in ('kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath^="{.data.password}"') do set ARGOCD_PASSWORD_B64=%%i
    for /f "tokens=*" %%i in ('powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('%ARGOCD_PASSWORD_B64%'))"') do set ARGOCD_PASSWORD=%%i

    echo.
    echo ================================================================
    echo                   ARGOCD ADMIN CREDENTIALS
    echo ================================================================
    echo Username: admin
    echo Password: !ARGOCD_PASSWORD!
    echo.
    echo SAVE THIS PASSWORD! You'll need it to login to ArgoCD
    echo ================================================================
    echo.

    echo [SUCCESS] ArgoCD installation completed!
) else (
    echo [WARNING] ArgoCD installation may still be in progress
    echo You can check status with: kubectl get pods -n argocd
)

echo.
pause
goto :MAIN_MENU

:APPLY_SECRETS
echo.
echo [INFO] Applying secrets and configmaps...
echo.

REM Create namespace first
echo [INFO] Creating message-publisher namespace...
kubectl create namespace message-publisher --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f k8s/secrets.yaml

if %errorLevel% equ 0 (
    echo [SUCCESS] Secrets and ConfigMap applied successfully!
) else (
    echo [ERROR] Failed to apply secrets. Make sure k8s/secrets.yaml exists.
)

echo.
pause
goto :MAIN_MENU

:PORT_FORWARD
echo.
echo [INFO] Setting up port forwarding...
echo.

REM Check if services exist
kubectl get svc -n argocd argocd-server >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] ArgoCD service not found. Please install ArgoCD first.
    pause
    goto :MAIN_MENU
)

kubectl get svc -n message-publisher message-publisher-frontend-service >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Frontend service not found. Please deploy the application first.
    pause
    goto :MAIN_MENU
)

REM Create frontend port forwarding script
echo @echo off > port-forward-frontend.bat
echo echo Starting frontend port forwarding... >> port-forward-frontend.bat
echo echo Access frontend at: http://localhost:3000 >> port-forward-frontend.bat
echo kubectl port-forward -n message-publisher svc/message-publisher-frontend-service 3000:80 >> port-forward-frontend.bat

REM Get ArgoCD password and create ArgoCD port forwarding script
for /f "tokens=*" %%i in ('kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath^="{.data.password}" 2^>nul') do set ARGOCD_PASSWORD_B64=%%i
for /f "tokens=*" %%i in ('powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('%ARGOCD_PASSWORD_B64%'))" 2^>nul') do set ARGOCD_PASSWORD=%%i
if "!ARGOCD_PASSWORD!"=="" set ARGOCD_PASSWORD=admin

echo @echo off > port-forward-argocd.bat
echo echo Starting ArgoCD port forwarding... >> port-forward-argocd.bat
echo echo Access ArgoCD at: https://localhost:8080 >> port-forward-argocd.bat
echo echo Username: admin >> port-forward-argocd.bat
echo echo Password: !ARGOCD_PASSWORD! >> port-forward-argocd.bat
echo kubectl port-forward -n argocd svc/argocd-server 8080:443 >> port-forward-argocd.bat

REM Create combined port forwarding script
echo @echo off > start-both-services.bat
echo echo Starting both port forwarding services... >> start-both-services.bat
echo echo. >> start-both-services.bat
echo echo Frontend will be available at: http://localhost:3000 >> start-both-services.bat
echo echo ArgoCD will be available at: https://localhost:8080 >> start-both-services.bat
echo echo. >> start-both-services.bat
echo echo ArgoCD Login: >> start-both-services.bat
echo echo Username: admin >> start-both-services.bat
echo echo Password: !ARGOCD_PASSWORD! >> start-both-services.bat
echo echo. >> start-both-services.bat
echo echo Press Ctrl+C to stop all services >> start-both-services.bat
echo echo. >> start-both-services.bat
echo start "Frontend" cmd /k "kubectl port-forward -n message-publisher svc/message-publisher-frontend-service 3000:80" >> start-both-services.bat
echo start "ArgoCD" cmd /k "kubectl port-forward -n argocd svc/argocd-server 8080:443" >> start-both-services.bat
echo echo Both services started in separate windows! >> start-both-services.bat
echo pause >> start-both-services.bat

echo [SUCCESS] Port forwarding scripts created!
echo Available scripts:
echo   port-forward-frontend.bat  - Start frontend port forwarding
echo   port-forward-argocd.bat    - Start ArgoCD port forwarding  
echo   start-both-services.bat    - Start both services
echo.

set /p start_now="Do you want to start port forwarding now? (y/N): "
if /I "!start_now!"=="y" (
    echo [INFO] Starting port forwarding for both services...
    start-both-services.bat
    goto :EXIT
)

echo.
pause
goto :MAIN_MENU

:FULL_SETUP
echo.
echo [INFO] Starting full setup...
echo.

call :INSTALL_TOOLS
call :START_DOCKER
call :CREATE_CLUSTER
call :INSTALL_ARGOCD
call :APPLY_SECRETS
call :PORT_FORWARD

goto :MAIN_MENU

:EXIT
echo.
echo [INFO] Goodbye!
echo.
pause
exit /b 0