@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM                MESSAGE PUBLISHER - COMPLETE WINDOWS SETUP
REM =============================================================================
REM This script sets up everything needed for local development:
REM 1. Installs all required software (Java, Node.js, Docker, kubectl, kind)
REM 2. Creates standardized Kind Kubernetes cluster  
REM 3. Installs and configures ArgoCD
REM 4. Sets up Jenkins agent connection
REM 5. Provides port forwarding commands for local access
REM =============================================================================

echo.
echo ================================================================
echo            MESSAGE PUBLISHER - WINDOWS SETUP
echo ================================================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click on the script and select "Run as administrator"
    pause
    exit /b 1
)

REM ====================
REM STEP 1: Install Software
REM ====================
echo [1/6] Installing required software...
echo.

REM Install Chocolatey if not present
where choco >nul 2>&1
if %errorLevel% neq 0 (
    echo Installing Chocolatey package manager...
    powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    call refreshenv
)

echo Installing Java 21...
choco install openjdk21 -y --force

echo Installing Node.js LTS...
choco install nodejs-lts -y --force

echo Installing Git...
choco install git -y --force

echo Installing kubectl...
choco install kubernetes-cli -y --force

echo Installing Kind...
choco install kind -y --force

echo Installing Docker Desktop...
choco install docker-desktop -y --force

REM Refresh environment variables
call refreshenv

echo.
echo Software installation completed!
echo.

REM ====================
REM STEP 2: Start Docker
REM ====================
echo [2/6] Starting Docker Desktop...
echo.

echo Please ensure Docker Desktop is running before continuing.
echo Check that the Docker icon in system tray shows "Docker Desktop is running"
echo.
pause

REM ====================
REM STEP 3: Create Kind Cluster
REM ====================
echo [3/6] Creating standardized Kind Kubernetes cluster...
echo.

REM Delete existing cluster if any
kind delete cluster --name message-publisher >nul 2>&1

REM Create cluster with standardized config
echo Creating cluster with standardized configuration...
kind create cluster --config=kind-cluster-config.yaml --name=message-publisher

if %errorLevel% neq 0 (
    echo ERROR: Failed to create Kind cluster
    echo Make sure Docker Desktop is running and try again
    pause
    exit /b 1
)

REM Verify cluster
kubectl cluster-info --context kind-message-publisher
kubectl get nodes

echo.
echo Kubernetes cluster created successfully!
echo.

REM ====================
REM STEP 4: Install ArgoCD
REM ====================
echo [4/6] Installing ArgoCD...
echo.

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo Waiting for ArgoCD to be ready (this may take 2-3 minutes)...
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

if %errorLevel% neq 0 (
    echo WARNING: ArgoCD installation may still be in progress
    echo You can check status with: kubectl get pods -n argocd
)

REM Get ArgoCD admin password
echo.
echo Getting ArgoCD admin password...
for /f "tokens=*" %%i in ('kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath^="{.data.password}"') do set ARGOCD_PASSWORD_B64=%%i

REM Decode base64 password using PowerShell
for /f "tokens=*" %%i in ('powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('%ARGOCD_PASSWORD_B64%'))"') do set ARGOCD_PASSWORD=%%i

echo.
echo ================================================================
echo                   ARGOCD ADMIN PASSWORD
echo ================================================================
echo Username: admin
echo Password: %ARGOCD_PASSWORD%
echo.
echo SAVE THIS PASSWORD! You'll need it to login to ArgoCD
echo ================================================================
echo.
pause

REM ====================
REM STEP 5: Jenkins Agent Setup
REM ====================
echo [5/6] Jenkins Agent Setup Instructions...
echo.

echo ================================================================
echo                 JENKINS AGENT CONNECTION
echo ================================================================
echo.
echo TO COMPLETE SETUP, YOU NEED:
echo.
echo 1. Agent connection details from your team lead:
echo    - Agent Name (e.g., windows-john-agent)
echo    - Connection Command with secret
echo.
echo 2. Download Jenkins agent:
echo    curl -O http://your-ec2-jenkins:8080/jnlpJars/agent.jar
echo.
echo 3. Start agent with provided command:
echo    java -jar agent.jar -jnlpUrl http://your-ec2:8080/computer/your-agent/jenkins-agent.jnlp -secret your-secret -workDir ./jenkins-work
echo.
echo 4. Upload your kubeconfig to Jenkins with credential ID:
echo    kubeconfig-kind-{your-agent-name}
echo.
echo ================================================================
echo.

REM Create jenkins work directory
mkdir C:\jenkins-work 2>nul

REM ====================
REM STEP 6: Port Forwarding Helper
REM ====================
echo [6/6] Creating port forwarding scripts...
echo.

REM Create frontend port forwarding script
echo @echo off > port-forward-frontend.bat
echo echo Starting frontend port forwarding... >> port-forward-frontend.bat
echo echo Access frontend at: http://localhost:3000 >> port-forward-frontend.bat
echo kubectl port-forward -n message-publisher svc/message-publisher-frontend 3000:80 >> port-forward-frontend.bat

REM Create ArgoCD port forwarding script
echo @echo off > port-forward-argocd.bat
echo echo Starting ArgoCD port forwarding... >> port-forward-argocd.bat
echo echo Access ArgoCD at: https://localhost:8080 >> port-forward-argocd.bat
echo echo Username: admin >> port-forward-argocd.bat
echo echo Password: %ARGOCD_PASSWORD% >> port-forward-argocd.bat
echo kubectl port-forward -n argocd svc/argocd-server 8080:443 >> port-forward-argocd.bat

REM Create API port forwarding script  
echo @echo off > port-forward-api.bat
echo echo Starting API port forwarding... >> port-forward-api.bat
echo echo Access API at: http://localhost:8000 >> port-forward-api.bat
echo kubectl port-forward -n message-publisher svc/message-publisher-api 8000:8000 >> port-forward-api.bat

REM Create combined port forwarding script
echo @echo off > start-all-services.bat
echo echo Starting all port forwarding services... >> start-all-services.bat
echo echo. >> start-all-services.bat
echo echo Frontend will be available at: http://localhost:3000 >> start-all-services.bat
echo echo ArgoCD will be available at: https://localhost:8080 >> start-all-services.bat
echo echo API will be available at: http://localhost:8000 >> start-all-services.bat
echo echo. >> start-all-services.bat
echo echo Press Ctrl+C to stop all services >> start-all-services.bat
echo echo. >> start-all-services.bat
echo start "Frontend" cmd /k "kubectl port-forward -n message-publisher svc/message-publisher-frontend 3000:80" >> start-all-services.bat
echo start "ArgoCD" cmd /k "kubectl port-forward -n argocd svc/argocd-server 8080:443" >> start-all-services.bat
echo start "API" cmd /k "kubectl port-forward -n message-publisher svc/message-publisher-api 8000:8000" >> start-all-services.bat
echo echo All services started in separate windows! >> start-all-services.bat
echo pause >> start-all-services.bat

echo.
echo ================================================================
echo                    SETUP COMPLETED!
echo ================================================================
echo.
echo WHAT'S BEEN SET UP:
echo ✓ Java 21, Node.js, Git, Docker, kubectl, Kind installed
echo ✓ Kind Kubernetes cluster 'message-publisher' created
echo ✓ ArgoCD installed and configured
echo ✓ Port forwarding scripts created
echo.
echo NEXT STEPS:
echo 1. Get Jenkins agent connection details from team lead
echo 2. Download and start Jenkins agent
echo 3. Upload kubeconfig to Jenkins credentials
echo 4. Run your first build in Jenkins
echo 5. Use port forwarding scripts to access applications:
echo.
echo    port-forward-frontend.bat  - Access frontend
echo    port-forward-argocd.bat    - Access ArgoCD  
echo    port-forward-api.bat       - Access API
echo    start-all-services.bat     - Start all services
echo.
echo ARGOCD LOGIN:
echo Username: admin
echo Password: %ARGOCD_PASSWORD%
echo.
echo DOCUMENTATION: See TEAM_SETUP_GUIDE.md for detailed instructions
echo.
echo ================================================================
echo.
pause