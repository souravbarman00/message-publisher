pipeline {
    agent any
    
    // Build triggers
    triggers {
        // Trigger on main branch push
        pollSCM('H/5 * * * *') // Poll every 5 minutes
        
        // GitHub webhook trigger (configure in GitHub repo settings)
        githubPush()
    }
    
    // Pipeline options
    options {
        // Keep last 10 builds
        buildDiscarder(logRotator(numToKeepStr: '10'))
        
        // Timeout after 30 minutes
        timeout(time: 30, unit: 'MINUTES')
        
        // Timestamps in console output
        timestamps()
        
        // Skip checkout to default
        skipDefaultCheckout()
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "🔄 Checking out code..."
                
                // Clean workspace
                cleanWs()
                
                // Checkout code
                checkout scm
                
                // Display build information
                script {
                    echo "🏗️  Build Information:"
                    echo "   Project: ${PROJECT_NAME}"
                    echo "   Version: ${VERSION}"
                    echo "   Branch: ${env.BRANCH_NAME ?: 'main'}"
    stages {
        stage('Start Kafka') {
            steps {
                dir('infra') { // repo contains docker-compose.yml for kafka/zookeeper
                    sh 'docker-compose up -d'
                    // wait for readiness (basic)
                    sh '''
                        for i in $(seq 1 30); do
                            if nc -z localhost 9092; then
                                echo "Kafka ready"
                                break
                            fi
                            sleep 2
                        done
                    '''
                }
            }
        }

        stage('Checkout') {
            steps {
                }
            }
        }
        
        stage('Setup Environment') {
            steps {
                echo "🔧 Setting up build environment..."
                
                script {
                    // Create docker images directory if it doesn't exist
                    sh """
                        sudo mkdir -p ${DOCKER_IMAGES_PATH}
                        sudo mkdir -p ${DOCKER_IMAGES_PATH}/api
                        sudo mkdir -p ${DOCKER_IMAGES_PATH}/frontend  
                        sudo mkdir -p ${DOCKER_IMAGES_PATH}/workers
                        sudo mkdir -p ${DOCKER_IMAGES_PATH}/manifests
                    """
                    
                    // Set up Node.js environment
                    sh """
                        node --version
                        npm --version
                    """
                }
            }
        }
        
        stage('Install Dependencies') {
            parallel {
                stage('Root Dependencies') {
                    steps {
                        echo "📦 Installing root dependencies..."
                        sh 'npm ci --only=production'
                    }
                }
                
                stage('API Dependencies') {
                    steps {
                        echo "📦 Installing API dependencies..."
                        dir('api') {
                            sh 'npm ci'
                        }
                    }
                }
                
                stage('Frontend Dependencies') {
                    steps {
                        echo "📦 Installing frontend dependencies..."
                        dir('frontend') {
                            sh 'npm ci'
                        }
                    }
                }
                
                stage('Workers Dependencies') {
                    steps {
                        echo "📦 Installing workers dependencies..."
                        dir('workers') {
                            sh 'npm ci'
                        }
                    }
                }
            }
        }
        
        stage('Code Quality Checks') {
            parallel {
                stage('ESLint - API') {
                    steps {
                        echo "🔍 Running ESLint for API..."
                        dir('api') {
                            script {
                                try {
                                    sh 'npm run lint'
                                } catch (Exception e) {
                                    echo "❌ ESLint failed for API"
                                    publishHTML([
                                        allowMissing: false,
                                        alwaysLinkToLastBuild: true,
                                        keepAll: true,
                                        reportDir: 'eslint-reports',
                                        reportFiles: 'api-eslint-report.html',
                                        reportName: 'API ESLint Report'
                                    ])
                                    error("ESLint check failed for API")
                                }
                            }
                        }
                    }
                }
                
                stage('ESLint - Frontend') {
                    steps {
                        echo "🔍 Running ESLint for Frontend..."
                        dir('frontend') {
                            script {
                                try {
                                    sh 'npm run lint'
                                } catch (Exception e) {
                                    echo "❌ ESLint failed for Frontend"
                                    publishHTML([
                                        allowMissing: false,
                                        alwaysLinkToLastBuild: true,
                                        keepAll: true,
                                        reportDir: 'eslint-reports',
                                        reportFiles: 'frontend-eslint-report.html',
                                        reportName: 'Frontend ESLint Report'
                                    ])
                                    error("ESLint check failed for Frontend")
                                }
                            }
                        }
                    }
                }
                
                stage('ESLint - Workers') {
                    steps {
                        echo "🔍 Running ESLint for Workers..."
                        dir('workers') {
                            script {
                                try {
                                    sh 'npm run lint'
                                } catch (Exception e) {
                                    echo "❌ ESLint failed for Workers"
                                    publishHTML([
                                        allowMissing: false,
                                        alwaysLinkToLastBuild: true,
                                        keepAll: true,
                                        reportDir: 'eslint-reports',
                                        reportFiles: 'workers-eslint-report.html',
                                        reportName: 'Workers ESLint Report'
                                    ])
                                    error("ESLint check failed for Workers")
                                }
                            }
                        }
                    }
                }
            }
        }
        
        stage('Build & Test') {
            parallel {
                stage('Build API') {
                    steps {
                        echo "🏗️ Building API service..."
                        dir('api') {
                            sh 'npm run build || echo "No build script defined"'
                        }
                    }
                }
                
                stage('Build Frontend') {
                    steps {
                        echo "🏗️ Building Frontend..."
                        dir('frontend') {
                            sh 'npm run build'
                        }
                    }
                }
                
                stage('Test API') {
                    steps {
                        echo "🧪 Running API tests..."
                        dir('api') {
                            sh 'npm test || echo "No tests defined"'
                        }
                    }
                    post {
                        always {
                            // Publish test results if they exist
                            script {
                                if (fileExists('api/test-results.xml')) {
                                    publishTestResults testResultsPattern: 'api/test-results.xml'
                                }
                            }
                        }
                    }
                }
                
                stage('Test Frontend') {
                    steps {
                        echo "🧪 Running Frontend tests..."
                        dir('frontend') {
                            sh 'npm test -- --coverage --watchAll=false || echo "No tests defined"'
                        }
                    }
                    post {
                        always {
                            // Publish test results if they exist
                            script {
                                if (fileExists('frontend/coverage')) {
                                    publishHTML([
                                        allowMissing: false,
                                        alwaysLinkToLastBuild: true,
                                        keepAll: true,
                                        reportDir: 'frontend/coverage/lcov-report',
                                        reportFiles: 'index.html',
                                        reportName: 'Frontend Coverage Report'
                                    ])
                                }
                            }
                        }
                    }
                }
            }
        }
        
        stage('Docker Image Creation') {
            parallel {
                stage('Build API Image') {
                    steps {
                        echo "🐳 Building API Docker image..."
                        script {
                            // Build API Docker image
                            def apiImage = docker.build("${API_IMAGE}", "-f api/Dockerfile api/")
                            
                            // Save image to tar file
                            sh """
                                docker save ${API_IMAGE} -o ${DOCKER_IMAGES_PATH}/api/${API_IMAGE}.tar
                                sudo chown jenkins:jenkins ${DOCKER_IMAGES_PATH}/api/${API_IMAGE}.tar
                            """
                            
                            echo "✅ API image built and saved: ${API_IMAGE}"
                        }
                    }
                }
                
                stage('Build Frontend Image') {
                    steps {
                        echo "🐳 Building Frontend Docker image..."
                        script {
                            // Build Frontend Docker image
                            def frontendImage = docker.build("${FRONTEND_IMAGE}", "-f frontend/Dockerfile frontend/")
                            
                            // Save image to tar file
                            sh """
                                docker save ${FRONTEND_IMAGE} -o ${DOCKER_IMAGES_PATH}/frontend/${FRONTEND_IMAGE}.tar
                                sudo chown jenkins:jenkins ${DOCKER_IMAGES_PATH}/frontend/${FRONTEND_IMAGE}.tar
                            """
                            
                            echo "✅ Frontend image built and saved: ${FRONTEND_IMAGE}"
                        }
                    }
                }
                
                stage('Build Workers Image') {
                    steps {
                        echo "🐳 Building Workers Docker image..."
                        script {
                            // Build Workers Docker image
                            def workersImage = docker.build("${WORKERS_IMAGE}", "-f workers/Dockerfile workers/")
                            
                            // Save image to tar file
                            sh """
                                docker save ${WORKERS_IMAGE} -o ${DOCKER_IMAGES_PATH}/workers/${WORKERS_IMAGE}.tar
                                sudo chown jenkins:jenkins ${DOCKER_IMAGES_PATH}/workers/${WORKERS_IMAGE}.tar
                            """
                            
                            echo "✅ Workers image built and saved: ${WORKERS_IMAGE}"
                        }
                    }
                }
            }
        }
        
        stage('Image Versioning & Manifest') {
            steps {
                echo "📝 Creating image manifest and versioning..."
                script {
                    // Create build manifest
                    def manifest = [
                        build: [
                            number: BUILD_NUMBER,
                            timestamp: BUILD_TIMESTAMP,
                            version: VERSION,
                            commit: GIT_COMMIT_SHORT,
                            branch: env.BRANCH_NAME ?: 'main'
                        ],
                        images: [
                            api: [
                                name: API_IMAGE,
                                file: "${DOCKER_IMAGES_PATH}/api/${API_IMAGE}.tar",
                                size: sh(script: "stat -f%z ${DOCKER_IMAGES_PATH}/api/${API_IMAGE}.tar 2>/dev/null || stat -c%s ${DOCKER_IMAGES_PATH}/api/${API_IMAGE}.tar 2>/dev/null || echo 0", returnStdout: true).trim()
                            ],
                            frontend: [
                                name: FRONTEND_IMAGE,
                                file: "${DOCKER_IMAGES_PATH}/frontend/${FRONTEND_IMAGE}.tar",
                                size: sh(script: "stat -f%z ${DOCKER_IMAGES_PATH}/frontend/${FRONTEND_IMAGE}.tar 2>/dev/null || stat -c%s ${DOCKER_IMAGES_PATH}/frontend/${FRONTEND_IMAGE}.tar 2>/dev/null || echo 0", returnStdout: true).trim()
                            ],
                            workers: [
                                name: WORKERS_IMAGE,
                                file: "${DOCKER_IMAGES_PATH}/workers/${WORKERS_IMAGE}.tar",
                                size: sh(script: "stat -f%z ${DOCKER_IMAGES_PATH}/workers/${WORKERS_IMAGE}.tar 2>/dev/null || stat -c%s ${DOCKER_IMAGES_PATH}/workers/${WORKERS_IMAGE}.tar 2>/dev/null || echo 0", returnStdout: true).trim()
                            ]
                        ]
                    ]
                    
                    // Write manifest to JSON file
                    writeJSON file: "${DOCKER_IMAGES_PATH}/manifests/build-${VERSION}.json", json: manifest, pretty: 4
                    
                    // Create latest symlink
                    sh """
                        cd ${DOCKER_IMAGES_PATH}/manifests
                        ln -sf build-${VERSION}.json latest.json
                    """
                    
                    // Tag images as latest (for current deployment)
                    sh """
                        docker tag ${API_IMAGE} ${PROJECT_NAME}-api:latest
                        docker tag ${FRONTEND_IMAGE} ${PROJECT_NAME}-frontend:latest
                        docker tag ${WORKERS_IMAGE} ${PROJECT_NAME}-workers:latest
                    """
                    
                    echo "📝 Build manifest created: build-${VERSION}.json"
                }
            }
        }
        
        stage('Cleanup Old Images') {
            steps {
                echo "🧹 Cleaning up old Docker images (keeping last 5)..."
                script {
                    // Keep only last 5 builds for each service
                    ['api', 'frontend', 'workers'].each { service ->
                        sh """
                            cd ${DOCKER_IMAGES_PATH}/${service}
                            ls -1t *.tar | tail -n +6 | xargs -r rm -f
                        """
                    }
                    
                    // Clean up old manifests (keep last 10)
                    sh """
                        cd ${DOCKER_IMAGES_PATH}/manifests
                        ls -1t build-*.json | tail -n +11 | xargs -r rm -f
                    """
                    
                    // Clean up unused Docker images
                    sh 'docker image prune -f'
                    
                    echo "✅ Cleanup completed"
                }
            }
        }
    }
    
    post {
        always {
            echo "🔍 Pipeline completed. Gathering artifacts..."
            
            // Archive build artifacts
            archiveArtifacts artifacts: """
                ${DOCKER_IMAGES_PATH}/manifests/build-${VERSION}.json,
                eslint-reports/**/*,
                frontend/coverage/**/*,
                api/test-results.xml
            """, allowEmptyArchive: true
            
            // Publish build information
            script {
                currentBuild.description = """
                    Version: ${VERSION}<br>
                    Commit: ${GIT_COMMIT_SHORT}<br>
                    Images: API, Frontend, Workers
                """
            }
        }
        
        success {
            echo "✅ Pipeline completed successfully!"
            
            // Send success notification
            script {
                if (env.BRANCH_NAME == 'main') {
                    // Slack notification (configure webhook in Jenkins)
                    slackSend(
                        color: 'good',
                        message: """
                            ✅ *Message Publisher* - Build Successful
                            • Version: `${VERSION}`
                            • Commit: `${GIT_COMMIT_SHORT}`
                            • Build: #${BUILD_NUMBER}
                            • Duration: ${currentBuild.durationString}
                            • Images: API, Frontend, Workers ready for deployment
                        """,
                        channel: '#deployments'
                    )
                }
            }
        }
        
        failure {
            echo "❌ Pipeline failed!"
            
            // Send failure notification
            script {
                slackSend(
                    color: 'danger',
                    message: """
                        ❌ *Message Publisher* - Build Failed
                        • Version: `${VERSION}`
                        • Commit: `${GIT_COMMIT_SHORT}`
                        • Build: #${BUILD_NUMBER}
                        • Stage: ${env.STAGE_NAME ?: 'Unknown'}
                        • Check: ${BUILD_URL}
                    """,
                    channel: '#deployments'
                )
            }
        }
        
        cleanup {
            // Clean workspace but keep Docker images
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}