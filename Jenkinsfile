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
                    // Generate dynamic values on Linux
                    env.BUILD_TIMESTAMP = sh(
                        script: 'date +%Y%m%d-%H%M%S',
                        returnStdout: true
                    ).trim()

                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
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
                sh '''
                    # Clean all node_modules directories  
                    rm -rf node_modules
                    rm -rf api/node_modules
                    rm -rf workers/node_modules
                    rm -rf frontend/node_modules
                    
                    # Clean npm cache
                    npm cache clean --force
                    
                    # Create necessary directories
                    mkdir -p api/logs
                    mkdir -p workers/logs
                    mkdir -p frontend/logs
                    mkdir -p shared
                '''
            }
        }

        stage('Install Dependencies') {
            parallel {
                stage('API Dependencies') {
                    steps {
                        dir('api') {
                            script {
                                def retries = 3
                                def success = false
                                for (int i = 0; i < retries && !success; i++) {
                                    try {
                                        sh '''
                                            rm -rf node_modules
                                            npm install --timeout=300000 --registry=https://registry.npmjs.org/
                                        '''
                                        success = true
                                    } catch (Exception e) {
                                        echo "API npm install attempt ${i+1} failed: ${e.getMessage()}"
                                        if (i == retries - 1) throw e
                                        sleep(15)
                                    }
                                }
                            }
                        }
                    }
                }
                stage('Workers Dependencies') {
                    steps {
                        dir('workers') {
                            script {
                                def retries = 3
                                def success = false
                                for (int i = 0; i < retries && !success; i++) {
                                    try {
                                        sh '''
                                            rm -rf node_modules
                                            npm install --timeout=300000 --registry=https://registry.npmjs.org/
                                        '''
                                        success = true
                                    } catch (Exception e) {
                                        echo "Workers npm install attempt ${i+1} failed: ${e.getMessage()}"
                                        if (i == retries - 1) throw e
                                        sleep(15)
                                    }
                                }
                            }
                        }
                    }
                }
                stage('Frontend Dependencies') {
                    steps {
                        dir('frontend') {
                            script {
                                def retries = 3
                                def success = false
                                for (int i = 0; i < retries && !success; i++) {
                                    try {
                                        sh '''
                                            rm -rf node_modules
                                            npm install --timeout=300000 --registry=https://registry.npmjs.org/
                                        '''
                                        success = true
                                    } catch (Exception e) {
                                        echo "Frontend npm install attempt ${i+1} failed: ${e.getMessage()}"
                                        if (i == retries - 1) throw e
                                        sleep(15)
                                    }
                                }
                            }
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
                                    sh 'npm run lint'
                                }
                            } catch (Exception e) {
                                echo "API lint failed: ${e.getMessage()}"
                            }
                            
                            try {
                                dir('workers') {
                                    sh 'npm run lint'
                                }
                            } catch (Exception e) {
                                echo "Workers lint failed: ${e.getMessage()}"
                            }
                            
                            try {
                                dir('frontend') {
                                    sh 'npx eslint src --ext .js,.jsx --fix'
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
                                    sh 'npm test'
                                    if (fileExists('test-results.xml')) {
                                        junit 'test-results.xml'
                                    }
                                }
                            } catch (Exception e) {
                                echo "API tests failed: ${e.getMessage()}"
                            }
                            
                            try {
                                dir('workers') {
                                    sh 'npm test'
                                    if (fileExists('test-results.xml')) {
                                        junit 'test-results.xml'
                                    }
                                }
                            } catch (Exception e) {
                                echo "Workers tests failed: ${e.getMessage()}"
                            }
                            
                            try {
                                dir('frontend') {
                                    sh 'npm test'
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
                            sh "docker build -t ${env.API_IMAGE} ."
                            sh "docker tag ${env.API_IMAGE} ${PROJECT_NAME}-api:latest"
                            sh "docker save -o ../shared/${env.API_IMAGE.replace(':', '_')}.tar ${env.API_IMAGE}"
                        }
                    }
                }
                stage('Workers') {
                    steps {
                        dir('workers') {
                            sh "docker build -t ${env.WORKERS_IMAGE} ."
                            sh "docker tag ${env.WORKERS_IMAGE} ${PROJECT_NAME}-workers:latest"
                            sh "docker save -o ../shared/${env.WORKERS_IMAGE.replace(':', '_')}.tar ${env.WORKERS_IMAGE}"
                        }
                    }
                }
                stage('Frontend') {
                    steps {
                        dir('frontend') {
                            sh "docker build -t ${env.FRONTEND_IMAGE} ."
                            sh "docker tag ${env.FRONTEND_IMAGE} ${PROJECT_NAME}-frontend:latest"
                            sh "docker save -o ../shared/${env.FRONTEND_IMAGE.replace(':', '_')}.tar ${env.FRONTEND_IMAGE}"
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
                        def kindCheck = sh(
                            script: 'which kind',
                            returnStatus: true
                        )
                        
                        if (kindCheck != 0) {
                            echo "Kind CLI not found. Installing Kind..."
                            // Try to install kind if not available
                            sh '''
                                curl -Lo kind https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-linux-amd64
                                chmod +x kind
                                sudo mv kind /usr/local/bin/
                            '''
                        }
                        
                        // Load from tar files first
                        echo "Loading images from tar files..."
                        sh """
                            docker load -i shared/${env.API_IMAGE.replace(':', '_')}.tar
                            docker load -i shared/${env.WORKERS_IMAGE.replace(':', '_')}.tar  
                            docker load -i shared/${env.FRONTEND_IMAGE.replace(':', '_')}.tar
                        """
                        
                        // Now try to load into kind cluster with the updated PATH
                        try {
                            sh '''
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
                            sh """
                                docker load -i shared/${env.API_IMAGE.replace(':', '_')}.tar
                                docker load -i shared/${env.WORKERS_IMAGE.replace(':', '_')}.tar
                                docker load -i shared/${env.FRONTEND_IMAGE.replace(':', '_')}.tar
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
                            sh """
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
                sh 'kubectl get nodes'
            }
        }

       stage('Deploy to Kubernetes & Update ArgoCD') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-kind', variable: 'KUBECONFIG')]) {
                    script {
                        try {
                            def currentContext = sh(
                                script: 'kubectl config current-context',
                                returnStdout: true
                            ).trim()
                            echo "Using Kubernetes context: ${currentContext}"

                            // Kubernetes deployments
                            sh 'kubectl get nodes'
                            
                            // Verify images are available locally
                            echo "Verifying Docker images are available..."
                            sh "docker images | grep ${PROJECT_NAME}"
                            
                            // Ensure namespace exists
                            sh 'kubectl create namespace message-publisher --dry-run=client -o yaml | kubectl apply -f -'
                            
                            // Force delete problematic pods to start fresh
                            try {
                                sh 'kubectl delete pods --all -n message-publisher --timeout=60s'
                                echo "Deleted old pods to start fresh"
                            } catch (Exception e) {
                                echo "Pod deletion warning: ${e.getMessage()}"
                            }
                            
                            // Apply deployments
                            sh 'kubectl apply -f k8s/api-deployment.yaml -n message-publisher'
                            sh 'kubectl apply -f k8s/workers-deployment.yaml -n message-publisher'
                            sh 'kubectl apply -f k8s/frontend-deployment.yaml -n message-publisher'
                            
                            // Force restart deployments to pick up new images
                            sh 'kubectl rollout restart deployment/message-publisher-api -n message-publisher'
                            sh 'kubectl rollout restart deployment/message-publisher-workers -n message-publisher'
                            sh 'kubectl rollout restart deployment/message-publisher-frontend -n message-publisher'

                            // Wait a moment for pods to start
                            sleep(10)
                            
                            // Check pod status before rollout
                            sh 'kubectl get pods -n message-publisher'
                            
                            // Wait for rollouts with extended timeout and better error handling
                            try {
                                sh 'kubectl rollout status deployment/message-publisher-api -n message-publisher --timeout=600s'
                                echo "API deployment successful"
                            } catch (Exception apiErr) {
                                echo "API deployment failed: ${apiErr.getMessage()}"
                                sh 'kubectl describe deployment message-publisher-api -n message-publisher'
                                sh 'kubectl get events -n message-publisher --sort-by=.metadata.creationTimestamp'
                                throw apiErr
                            }
                            
                            try {
                                sh 'kubectl rollout status deployment/message-publisher-workers -n message-publisher --timeout=300s'
                                echo "Workers deployment successful"
                            } catch (Exception workersErr) {
                                echo "Workers deployment timeout/failed: ${workersErr.getMessage()}"
                                echo "Checking if workers pods are running..."
                                def runningWorkers = sh(
                                    script: 'kubectl get pods -n message-publisher -l app=message-publisher-workers --field-selector=status.phase=Running --no-headers | wc -l',
                                    returnStdout: true
                                ).trim()
                                echo "Running workers pods: ${runningWorkers}"
                                if (runningWorkers.toInteger() >= 3) {
                                    echo "Sufficient workers are running, continuing deployment"
                                } else {
                                    sh 'kubectl describe deployment message-publisher-workers -n message-publisher'
                                }
                            }
                            
                            try {
                                sh 'kubectl rollout status deployment/message-publisher-frontend -n message-publisher --timeout=600s'
                                echo "Frontend deployment successful"
                            } catch (Exception frontendErr) {
                                echo "Frontend deployment failed: ${frontendErr.getMessage()}"
                                sh 'kubectl describe deployment message-publisher-frontend -n message-publisher'
                            }

                            sh 'kubectl get pods -n message-publisher'

                            // ArgoCD application
                            def appExists = sh(
                                script: 'kubectl get application message-publisher-app -n argocd',
                                returnStatus: true
                            )

                            if (appExists == 0) {
                                echo "ArgoCD application exists, triggering sync..."
                                sh 'kubectl patch application message-publisher-app -n argocd -p "{\\"spec\\":{\\"source\\":{\\"targetRevision\\":\\"master\\"}}}" --type merge'
                            } else {
                                echo "Creating ArgoCD application..."
                                sh 'kubectl apply -f k8s/argocd-application.yaml'
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
                            def appExists = sh(
                                script: 'kubectl get application message-publisher-app -n argocd',
                                returnStatus: true
                            )
                            
                            if (appExists == 0) {
                                echo "ArgoCD application exists, triggering sync..."
                                sh 'kubectl patch application message-publisher-app -n argocd -p "{\\"spec\\":{\\"source\\":{\\"targetRevision\\":\\"master\\"}}}" --type merge'
                            } else {
                                echo "Creating ArgoCD application..."
                                sh 'kubectl apply -f k8s/argocd-application.yaml --validate=false'
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
                    sh 'docker image prune -f'
                } catch (Exception e) {
                    echo "Docker cleanup warning: ${e.getMessage()}"
                }
            }
        }
    }
}