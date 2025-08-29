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
                       Branch: ${env.BRANCH_NAME ?: 'main'}
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
                            bat "docker save -o ..\\shared\\${env.API_IMAGE.replace(':', '_')}.tar ${env.API_IMAGE}"
                        }
                    }
                }
                stage('Workers') {
                    steps {
                        dir('workers') {
                            bat "docker build -t ${env.WORKERS_IMAGE} ."
                            bat "docker save -o ..\\shared\\${env.WORKERS_IMAGE.replace(':', '_')}.tar ${env.WORKERS_IMAGE}"
                        }
                    }
                }
                stage('Frontend') {
                    steps {
                        dir('frontend') {
                            bat "docker build -t ${env.FRONTEND_IMAGE} ."
                            bat "docker save -o ..\\shared\\${env.FRONTEND_IMAGE.replace(':', '_')}.tar ${env.FRONTEND_IMAGE}"
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
                        branch    : env.BRANCH_NAME ?: 'main',
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

       stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-kind', variable: 'KUBECONFIG')]) {
                    script {
                        try {
                            def currentContext = bat(
                                script: 'kubectl config current-context',
                                returnStdout: true
                            ).trim()
                            
                            echo "Using Kubernetes context: ${currentContext}"
                            
                            bat 'kubectl get nodes'
                            bat 'kubectl apply -f k8s/api-deployment.yaml -n message-publisher'
                            bat 'kubectl apply -f k8s/workers-deployment.yaml -n message-publisher'
                            bat 'kubectl apply -f k8s/frontend-deployment.yaml -n message-publisher'
                            
                            bat 'kubectl rollout status deployment/message-publisher-api -n message-publisher --timeout=300s'
                            bat 'kubectl rollout status deployment/message-publisher-workers -n message-publisher --timeout=300s'
                            bat 'kubectl rollout status deployment/message-publisher-frontend -n message-publisher --timeout=300s'
                            
                            bat 'kubectl get pods -n message-publisher'
                        } catch (Exception e) {
                            echo "Kubernetes deployment failed: ${e.getMessage()}"
                            currentBuild.result = 'UNSTABLE'
                        }
                    }
                }
            }
        }
        stage('Update ArgoCD Application') {
            steps {
                script {
                    try {
                        // Check if ArgoCD application exists
                        def appExists = bat(
                            script: 'kubectl get application message-publisher-app -n argocd',
                            returnStatus: true
                        )
                        
                        if (appExists == 0) {
                            echo "ArgoCD application exists, triggering sync..."
                            // Trigger ArgoCD sync via kubectl
                            bat 'kubectl patch application message-publisher-app -n argocd -p "{\\"spec\\":{\\"source\\":{\\"targetRevision\\":\\"main\\"}}}" --type merge'
                        } else {
                            echo "Creating ArgoCD application..."
                            bat 'kubectl apply -f k8s/argocd-application.yaml'
                        }
                        
                        echo "ArgoCD application updated successfully"
                        
                    } catch (Exception e) {
                        echo "ArgoCD update failed: ${e.getMessage()}"
                        echo "You can manually sync the application in ArgoCD UI"
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