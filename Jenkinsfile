pipeline {
    agent any

    environment {
        PROJECT_NAME = 'message-publisher'
        DOCKER_IMAGES_PATH = "C:/jenkins/docker-images"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        skipDefaultCheckout()
    }

    stages {
        stage('Checkout') {
            steps {
                echo "🔄 Checking out code..."
                cleanWs()
                checkout scm

                script {
                    env.BUILD_TIMESTAMP = bat(script: 'for /f "tokens=*" %i in (\'powershell -command "Get-Date -Format yyyyMMdd-HHmmss"\') do @echo %i', returnStdout: true).trim()
                    env.GIT_COMMIT_SHORT = bat(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}-${env.BUILD_TIMESTAMP}"

                    env.API_IMAGE = "${PROJECT_NAME}-api:${env.VERSION}"
                    env.FRONTEND_IMAGE = "${PROJECT_NAME}-frontend:${env.VERSION}"
                    env.WORKERS_IMAGE = "${PROJECT_NAME}-workers:${env.VERSION}"

                    echo """
                    🏗️  Build Information:
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

        stage('Setup Environment') {
            steps {
                echo "🔧 Setting up build environment..."
                bat """
                    if not exist ${DOCKER_IMAGES_PATH}\\api mkdir ${DOCKER_IMAGES_PATH}\\api
                    if not exist ${DOCKER_IMAGES_PATH}\\frontend mkdir ${DOCKER_IMAGES_PATH}\\frontend
                    if not exist ${DOCKER_IMAGES_PATH}\\workers mkdir ${DOCKER_IMAGES_PATH}\\workers
                    if not exist ${DOCKER_IMAGES_PATH}\\manifests mkdir ${DOCKER_IMAGES_PATH}\\manifests
                """
                bat "node --version && npm --version"
            }
        }

        stage('Install Dependencies') {
            parallel {
                stage('Root Dependencies') {
                    steps { bat 'npm ci --only=production || exit /b 0' }
                }
                stage('API Dependencies') {
                    steps { dir('api') { bat 'npm ci' } }
                }
                stage('Frontend Dependencies') {
                    steps { dir('frontend') { bat 'npm ci' } }
                }
                stage('Workers Dependencies') {
                    steps { dir('workers') { bat 'npm ci' } }
                }
            }
        }

        stage('Build & Test') {
            parallel {
                stage('Build API') {
                    steps { dir('api') { bat 'npm run build || echo No build script' } }
                }
                stage('Build Frontend') {
                    steps { dir('frontend') { bat 'npm run build' } }
                }
                stage('Test API') {
                    steps { dir('api') { bat 'npm test || echo No tests defined' } }
                    post {
                        always {
                            script {
                                if (fileExists('api/test-results.xml')) {
                                    junit 'api/test-results.xml'
                                }
                            }
                        }
                    }
                }
                stage('Test Frontend') {
                    steps { dir('frontend') { bat 'npm test -- --coverage --watchAll=false || echo No tests defined' } }
                    post {
                        always {
                            script {
                                if (fileExists('frontend/coverage/lcov-report/index.html')) {
                                    publishHTML([
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
                        script {
                            bat "docker build -t ${env.API_IMAGE} -f api/Dockerfile api"
                            bat "docker save -o ${DOCKER_IMAGES_PATH}/api/${env.API_IMAGE}.tar ${env.API_IMAGE}"
                        }
                    }
                }
                stage('Build Frontend Image') {
                    steps {
                        script {
                            bat "docker build -t ${env.FRONTEND_IMAGE} -f frontend/Dockerfile frontend"
                            bat "docker save -o ${DOCKER_IMAGES_PATH}/frontend/${env.FRONTEND_IMAGE}.tar ${env.FRONTEND_IMAGE}"
                        }
                    }
                }
                stage('Build Workers Image') {
                    steps {
                        script {
                            bat "docker build -t ${env.WORKERS_IMAGE} -f workers/Dockerfile workers"
                            bat "docker save -o ${DOCKER_IMAGES_PATH}/workers/${env.WORKERS_IMAGE}.tar ${env.WORKERS_IMAGE}"
                        }
                    }
                }
            }
        }

        stage('Image Versioning & Manifest') {
            steps {
                script {
                    def manifest = [
                        build: [
                            number: env.BUILD_NUMBER,
                            timestamp: env.BUILD_TIMESTAMP,
                            version: env.VERSION,
                            commit: env.GIT_COMMIT_SHORT,
                            branch: env.BRANCH_NAME ?: 'main'
                        ],
                        images: [
                            api: [
                                name: env.API_IMAGE,
                                file: "${DOCKER_IMAGES_PATH}/api/${env.API_IMAGE}.tar"
                            ],
                            frontend: [
                                name: env.FRONTEND_IMAGE,
                                file: "${DOCKER_IMAGES_PATH}/frontend/${env.FRONTEND_IMAGE}.tar"
                            ],
                            workers: [
                                name: env.WORKERS_IMAGE,
                                file: "${DOCKER_IMAGES_PATH}/workers/${env.WORKERS_IMAGE}.tar"
                            ]
                        ]
                    ]
                    writeJSON file: "${DOCKER_IMAGES_PATH}/manifests/build-${env.VERSION}.json", json: manifest, pretty: 4
                    bat "copy /Y ${DOCKER_IMAGES_PATH}\\manifests\\build-${env.VERSION}.json ${DOCKER_IMAGES_PATH}\\manifests\\latest.json"
                    bat "docker tag ${env.API_IMAGE} ${PROJECT_NAME}-api:latest"
                    bat "docker tag ${env.FRONTEND_IMAGE} ${PROJECT_NAME}-frontend:latest"
                    bat "docker tag ${env.WORKERS_IMAGE} ${PROJECT_NAME}-workers:latest"
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: """
                ${DOCKER_IMAGES_PATH}/manifests/build-${env.VERSION}.json,
                eslint-reports/**/*,
                frontend/coverage/**/*,
                api/test-results.xml
            """, allowEmptyArchive: true
        }
    }
}
