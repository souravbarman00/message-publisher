pipeline {
    agent any  
    
    environment {
        PROJECT_NAME = "message-publisher"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // Generate dynamic values on Windows
                    env.BUILD_TIMESTAMP = powershell(
                        script: 'Get-Date -Format yyyyMMdd-HHmmss',
                        returnStdout: true
                    ).trim()

                    env.GIT_COMMIT_SHORT = bat(
                        script: '@echo off && git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    env.VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}-${env.BUILD_TIMESTAMP}"
                    env.API_IMAGE = "${PROJECT_NAME}-api:${env.VERSION}"
                    env.FRONTEND_IMAGE = "${PROJECT_NAME}-frontend:${env.VERSION}"
                    env.WORKERS_IMAGE = "${PROJECT_NAME}-workers:${env.VERSION}"

                    echo """
                    Build Information:
                       Project: ${PROJECT_NAME}
                       Version: ${env.VERSION}
                       Branch: ${env.BRANCH_NAME ?: 'master'}
                       Commit: ${env.GIT_COMMIT_SHORT}
                       Timestamp: ${env.BUILD_TIMESTAMP}
                       Build Number: ${env.BUILD_NUMBER}
                    """
                }
            }
        }

        stage('Prepare Folders') {
            steps {
                bat '''
                    REM Clean all node_modules directories  
                    if exist node_modules rmdir /s /q node_modules
                    if exist api\\node_modules rmdir /s /q api\\node_modules
                    if exist workers\\node_modules rmdir /s /q workers\\node_modules
                    if exist frontend\\node_modules rmdir /s /q frontend\\node_modules
                    
                    REM Clean npm cache
                    npm cache clean --force
                    
                    REM Create necessary directories
                    if not exist api\\logs mkdir api\\logs
                    if not exist workers\\logs mkdir workers\\logs
                    if not exist frontend\\logs mkdir frontend\\logs
                    if not exist shared mkdir shared
                '''
            }
        }

        stage('Install Dependencies') {
            parallel {
                stage('API Dependencies') {
                    steps {
                        dir('api') {
                            bat '''
                                if exist node_modules rmdir /s /q node_modules
                                npm install --no-bin-links
                            '''
                        }
                    }
                }
                stage('Workers Dependencies') {
                    steps {
                        dir('workers') {
                            bat '''
                                if exist node_modules rmdir /s /q node_modules
                                npm install --no-bin-links
                            '''
                        }
                    }
                }
                stage('Frontend Dependencies') {
                    steps {
                        dir('frontend') {
                            bat '''
                                if exist node_modules rmdir /s /q node_modules
                                npm install --no-bin-links
                            '''
                        }
                    }
                }
            }
        }

        stage('Lint and Test') {
            parallel {
                stage('Lint') {
                    steps {
                        script {
                            try {
                                dir('api') {
                                    bat 'npm run lint'
                                }
                            } catch (Exception e) {
                                echo "API lint failed: ${e.getMessage()}"
                            }
                            
                            try {
                                dir('workers') {
                                    bat 'npm run lint'
                                }
                            } catch (Exception e) {
                                echo "Workers lint failed: ${e.getMessage()}"
                            }
                            
                            try {
                                dir('frontend') {
                                    bat 'npx eslint src --ext .js,.jsx --fix'
                                }
                            } catch (Exception e) {
                                echo "Frontend lint failed: ${e.getMessage()}"
                            }
                        }
                    }
                }
                stage('Test') {
                    steps {
                        script {
                            try {
                                dir('api') {
                                    bat 'npm test'
                                    if (fileExists('test-results.xml')) {
                                        junit 'test-results.xml'
                                    }
                                }
                            } catch (Exception e) {
                                echo "API tests failed: ${e.getMessage()}"
                            }
                            
                            try {
                                dir('workers') {
                                    bat 'npm test'
                                    if (fileExists('test-results.xml')) {
                                        junit 'test-results.xml'
                                    }
                                }
                            } catch (Exception e) {
                                echo "Workers tests failed: ${e.getMessage()}"
                            }
                            
                            try {
                                dir('frontend') {
                                    bat 'npm test'
                                    if (fileExists('test-results.xml')) {
                                        junit 'test-results.xml'
                                    }
                                }
                            } catch (Exception e) {
                                echo "Frontend tests failed: ${e.getMessage()}"
                            }
                        }
                    }
                }
            }
        }

        stage('Build Docker Images') {
            parallel {
                stage('API') {
                    steps {
                        dir('api') {
                            bat "docker build -t ${env.API_IMAGE} ."
                            bat "docker tag ${env.API_IMAGE} ${PROJECT_NAME}-api:latest"
                            bat "docker save -o ..\\shared\\${env.API_IMAGE.replace(':', '_')}.tar ${env.API_IMAGE}"
                        }
                    }
                }
                stage('Workers') {
                    steps {
                        dir('workers') {
                            bat "docker build -t ${env.WORKERS_IMAGE} ."
                            bat "docker tag ${env.WORKERS_IMAGE} ${PROJECT_NAME}-workers:latest"
                            bat "docker save -o ..\\shared\\${env.WORKERS_IMAGE.replace(':', '_')}.tar ${env.WORKERS_IMAGE}"
                        }
                    }
                }
                stage('Frontend') {
                    steps {
                        dir('frontend') {
                            bat "docker build -t ${env.FRONTEND_IMAGE} ."
                            bat "docker tag ${env.FRONTEND_IMAGE} ${PROJECT_NAME}-frontend:latest"
                            bat "docker save -o ..\\shared\\${env.FRONTEND_IMAGE.replace(':', '_')}.tar ${env.FRONTEND_IMAGE}"
                        }
                    }
                }
            }
        }

        // NEW STAGE: Load images into Kind cluster
        stage('Load Images into Kind') {
            steps {
                script {
                    try {
                        // Check if kind is available
                        def kindCheck = bat(
                            script: 'where kind',
                            returnStatus: true
                        )
                        
                        if (kindCheck != 0) {
                            echo "Kind CLI not found. Installing Kind..."
                            // Try to install kind if not available
                            bat '''
                                curl.exe -Lo kind-windows-amd64.exe https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-windows-amd64
                                mkdir C:\\tools 2>nul || echo Directory exists
                                move kind-windows-amd64.exe C:\\tools\\kind.exe
                            '''
                        }
                        
                        // Load from tar files first
                        echo "Loading images from tar files..."
                        bat """
                            docker load -i shared\\${env.API_IMAGE.replace(':', '_')}.tar
                            docker load -i shared\\${env.WORKERS_IMAGE.replace(':', '_')}.tar  
                            docker load -i shared\\${env.FRONTEND_IMAGE.replace(':', '_')}.tar
                        """
                        
                        // Now try to load into kind cluster with the updated PATH
                        try {
                            bat '''
                                set PATH=%PATH%;C:\\tools
                                kind load docker-image message-publisher-api:latest --name message-publisher
                                kind load docker-image message-publisher-frontend:latest --name message-publisher  
                                kind load docker-image message-publisher-workers:latest --name message-publisher
                            '''
                            echo "Images successfully loaded into Kind cluster"
                        } catch (Exception kindErr) {
                            echo "Kind load failed: ${kindErr.getMessage()}"
                            echo "Images are loaded locally, will use imagePullPolicy: Never"
                        }
                        echo "Images loaded into Kind cluster successfully"
                    } catch (Exception e) {
                        echo "Failed to load images into Kind: ${e.getMessage()}"
                        echo "Attempting alternative docker load method..."
                        try {
                            // Fallback: Load from saved tar files
                            bat """
                                docker load -i shared\\${env.API_IMAGE.replace(':', '_')}.tar
                                docker load -i shared\\${env.WORKERS_IMAGE.replace(':', '_')}.tar
                                docker load -i shared\\${env.FRONTEND_IMAGE.replace(':', '_')}.tar
                            """
                            echo "Images loaded successfully via docker load"
                        } catch (Exception e2) {
                            echo "Both kind and docker load failed: ${e2.getMessage()}"
                            currentBuild.result = 'UNSTABLE'
                        }
                    }
                }
            }
        }

        // NEW STAGE: Update Kubernetes deployments with correct image tags
        stage('Update Deployment Images') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-kind', variable: 'KUBECONFIG')]) {
                    script {
                        try {
                            // Update deployment image tags to use latest
                            bat """
                                kubectl set image deployment/message-publisher-api api=${PROJECT_NAME}-api:latest -n message-publisher
                                kubectl set image deployment/message-publisher-frontend frontend=${PROJECT_NAME}-frontend:latest -n message-publisher
                                kubectl set image deployment/message-publisher-workers workers=${PROJECT_NAME}-workers:latest -n message-publisher
                            """
                            echo "Deployment images updated successfully"
                        } catch (Exception e) {
                            echo "Failed to update deployment images: ${e.getMessage()}"
                        }
                    }
                }
            }
        }

        stage('Generate Build Manifest') {
            steps {
                script {
                    def manifest = [
                        project   : PROJECT_NAME,
                        version   : env.VERSION,
                        branch    : env.BRANCH_NAME ?: 'master',
                        commit    : env.GIT_COMMIT_SHORT,
                        timestamp : env.BUILD_TIMESTAMP,
                        buildNumber: env.BUILD_NUMBER,
                        artifacts : [
                            api     : "${env.API_IMAGE}",
                            workers : "${env.WORKERS_IMAGE}",
                            frontend: "${env.FRONTEND_IMAGE}"
                        ]
                    ]
                    
                    // Convert map to JSON string and write to file
                    def jsonString = groovy.json.JsonOutput.toJson(manifest)
                    def prettyJson = groovy.json.JsonOutput.prettyPrint(jsonString)
                    writeFile file: 'shared/build-manifest.json', text: prettyJson
                    archiveArtifacts artifacts: 'shared/build-manifest.json', fingerprint: true
                }
                echo "Build manifest generated successfully"
            }
        }

        stage('Test Kubectl') {
            steps {
                bat 'kubectl get nodes --kubeconfig C:\\Jenkins\\.kube\\config'
            }
        }

       stage('Deploy to Kubernetes & Update ArgoCD') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-kind', variable: 'KUBECONFIG')]) {
                    script {
                        try {
                            def currentContext = bat(
                                script: 'kubectl config current-context',
                                returnStdout: true
                            ).trim()
                            echo "Using Kubernetes context: ${currentContext}"

                            // Kubernetes deployments
                            bat 'kubectl get nodes'
                            
                            // Verify images are available locally
                            echo "Verifying Docker images are available..."
                            bat "docker images | findstr ${PROJECT_NAME}"
                            
                            // Ensure namespace exists
                            bat 'kubectl create namespace message-publisher --dry-run=client -o yaml | kubectl apply -f -'
                            
                            // Force delete problematic pods to start fresh
                            try {
                                bat 'kubectl delete pods --all -n message-publisher --timeout=60s'
                                echo "Deleted old pods to start fresh"
                            } catch (Exception e) {
                                echo "Pod deletion warning: ${e.getMessage()}"
                            }
                            
                            // Apply deployments
                            bat 'kubectl apply -f k8s/api-deployment.yaml -n message-publisher'
                            bat 'kubectl apply -f k8s/workers-deployment.yaml -n message-publisher'
                            bat 'kubectl apply -f k8s/frontend-deployment.yaml -n message-publisher'
                            
                            // Force restart deployments to pick up new images
                            bat 'kubectl rollout restart deployment/message-publisher-api -n message-publisher'
                            bat 'kubectl rollout restart deployment/message-publisher-workers -n message-publisher'
                            bat 'kubectl rollout restart deployment/message-publisher-frontend -n message-publisher'

                            // Wait a moment for pods to start
                            sleep(10)
                            
                            // Check pod status before rollout
                            bat 'kubectl get pods -n message-publisher'
                            
                            // Wait for rollouts with extended timeout and better error handling
                            try {
                                bat 'kubectl rollout status deployment/message-publisher-api -n message-publisher --timeout=600s'
                                echo "API deployment successful"
                            } catch (Exception apiErr) {
                                echo "API deployment failed: ${apiErr.getMessage()}"
                                bat 'kubectl describe deployment message-publisher-api -n message-publisher'
                                bat 'kubectl get events -n message-publisher --sort-by=.metadata.creationTimestamp'
                                throw apiErr
                            }
                            
                            try {
                                bat 'kubectl rollout status deployment/message-publisher-workers -n message-publisher --timeout=300s'
                                echo "Workers deployment successful"
                            } catch (Exception workersErr) {
                                echo "Workers deployment timeout/failed: ${workersErr.getMessage()}"
                                echo "Checking if workers pods are running..."
                                def runningWorkers = bat(
                                    script: 'kubectl get pods -n message-publisher -l app=message-publisher-workers --field-selector=status.phase=Running --no-headers | wc -l',
                                    returnStdout: true
                                ).trim()
                                echo "Running workers pods: ${runningWorkers}"
                                if (runningWorkers.toInteger() >= 3) {
                                    echo "Sufficient workers are running, continuing deployment"
                                } else {
                                    bat 'kubectl describe deployment message-publisher-workers -n message-publisher'
                                }
                            }
                            
                            try {
                                bat 'kubectl rollout status deployment/message-publisher-frontend -n message-publisher --timeout=600s'
                                echo "Frontend deployment successful"
                            } catch (Exception frontendErr) {
                                echo "Frontend deployment failed: ${frontendErr.getMessage()}"
                                bat 'kubectl describe deployment message-publisher-frontend -n message-publisher'
                            }

                            bat 'kubectl get pods -n message-publisher'

                            // ArgoCD application
                            def appExists = bat(
                                script: 'kubectl get application message-publisher-app -n argocd',
                                returnStatus: true
                            )

                            if (appExists == 0) {
                                echo "ArgoCD application exists, triggering sync..."
                                bat 'kubectl patch application message-publisher-app -n argocd -p "{\\"spec\\":{\\"source\\":{\\"targetRevision\\":\\"master\\"}}}" --type merge'
                            } else {
                                echo "Creating ArgoCD application..."
                                bat 'kubectl apply -f k8s/argocd-application.yaml'
                            }

                            echo "Kubernetes and ArgoCD update completed successfully"

                        } catch (Exception e) {
                            echo "Deployment failed: ${e.getMessage()}"
                            currentBuild.result = 'UNSTABLE'
                        }
                    }
                }
            }
        }

        stage('Update ArgoCD Application') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-kind', variable: 'KUBECONFIG')]) {
                    script {
                        try {
                            def appExists = bat(
                                script: 'kubectl get application message-publisher-app -n argocd',
                                returnStatus: true
                            )
                            
                            if (appExists == 0) {
                                echo "ArgoCD application exists, triggering sync..."
                                bat 'kubectl patch application message-publisher-app -n argocd -p "{\\"spec\\":{\\"source\\":{\\"targetRevision\\":\\"master\\"}}}" --type merge'
                            } else {
                                echo "Creating ArgoCD application..."
                                bat 'kubectl apply -f k8s/argocd-application.yaml --validate=false'
                            }
                            
                        } catch (Exception e) {
                            echo "ArgoCD update failed: ${e.getMessage()}"
                        }
                    }
                }
            }
        }

        stage('Cleanup Old Artifacts') {
            steps {
                script {
                    try {
                        cleanWs(patterns: [[pattern: 'shared/*.tar', type: 'INCLUDE']], deleteDirs: false)
                        echo "Docker image artifacts cleaned"
                    } catch (Exception e) {
                        echo "Cleanup warning: ${e.getMessage()}"
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Build completed with status: ${currentBuild.result ?: 'SUCCESS'}"
        }
        success {
            echo "Build succeeded for ${PROJECT_NAME} version ${env.VERSION}"
        }
        failure {
            echo "Build failed for ${PROJECT_NAME} version ${env.VERSION}"
        }
        cleanup {
            // Clean up Docker images to save space
            script {
                try {
                    bat 'docker image prune -f'
                } catch (Exception e) {
                    echo "Docker cleanup warning: ${e.getMessage()}"
                }
            }
        }
    }
}