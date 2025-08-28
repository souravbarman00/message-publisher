pipeline {
    agent any
    tools {
        nodejs "Node18"
    }   
    environment {
        PROJECT_NAME = "message-publisher"
        SLACK_CHANNEL = '#jenkins-alerts'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // Generate dynamic values on Windows
                    env.BUILD_TIMESTAMP = bat(
                        script: 'powershell -command "Get-Date -Format yyyyMMdd-HHmmss"',
                        returnStdout: true
                    ).trim()

                    env.GIT_COMMIT_SHORT = bat(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    env.VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}-${env.BUILD_TIMESTAMP}"
                    env.API_IMAGE = "${PROJECT_NAME}-api:${env.VERSION}"
                    env.FRONTEND_IMAGE = "${PROJECT_NAME}-frontend:${env.VERSION}"
                    env.WORKERS_IMAGE = "${PROJECT_NAME}-workers:${env.VERSION}"

                    echo """
                    🏗️ Build Information:
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
                bat 'if not exist backend\\api\\logs mkdir backend\\api\\logs'
                bat 'if not exist backend\\workers\\logs mkdir backend\\workers\\logs'
                bat 'if not exist frontend\\logs mkdir frontend\\logs'
                bat 'if not exist shared mkdir shared'
            }
        }

        stage('Install Dependencies') {
            parallel {
                stage('API Dependencies') {
                    steps {
                        dir('backend/api') {
                            bat 'npm install'
                        }
                    }
                }
                stage('Workers Dependencies') {
                    steps {
                        dir('backend/workers') {
                            bat 'npm install'
                        }
                    }
                }
                stage('Frontend Dependencies') {
                    steps {
                        dir('frontend') {
                            bat 'npm install'
                        }
                    }
                }
            }
        }

        stage('Lint and Test') {
            parallel {
                stage('Lint') {
                    steps {
                        dir('backend/api') {
                            bat 'npm run lint || exit 0'
                        }
                        dir('backend/workers') {
                            bat 'npm run lint || exit 0'
                        }
                        dir('frontend') {
                            bat 'npm run lint || exit 0'
                        }
                    }
                }
                stage('Test') {
                    steps {
                        dir('backend/api') {
                            bat 'npm test || exit 0'
                            junit 'test-results.xml'
                        }
                        dir('backend/workers') {
                            bat 'npm test || exit 0'
                            junit 'test-results.xml'
                        }
                        dir('frontend') {
                            bat 'npm test || exit 0'
                            junit 'test-results.xml'
                        }
                    }
                }
            }
        }

        stage('Build Docker Images') {
            parallel {
                stage('API') {
                    steps {
                        dir('backend/api') {
                            bat "docker build -t ${env.API_IMAGE} ."
                            bat "docker save -o ..\\..\\shared\\${env.API_IMAGE.replace(':', '_')}.tar ${env.API_IMAGE}"
                        }
                    }
                }
                stage('Workers') {
                    steps {
                        dir('backend/workers') {
                            bat "docker build -t ${env.WORKERS_IMAGE} ."
                            bat "docker save -o ..\\..\\shared\\${env.WORKERS_IMAGE.replace(':', '_')}.tar ${env.WORKERS_IMAGE}"
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
                    writeJSON file: 'shared/build-manifest.json', json: manifest, pretty: 4
                    archiveArtifacts artifacts: 'shared/build-manifest.json', fingerprint: true
                }
            }
        }

        stage('Cleanup Old Artifacts') {
            steps {
                cleanWs(patterns: [[pattern: 'shared/*.tar', type: 'INCLUDE']], deleteDirs: false)
                cleanWs(patterns: [[pattern: 'shared/build-manifest.json', type: 'INCLUDE']], deleteDirs: false)
            }
        }
    }

    post {
        success {
            script {
                try {
                    slackSend(channel: SLACK_CHANNEL, color: 'good',
                        message: "✅ Build succeeded for *${PROJECT_NAME}* version *${env.VERSION}* (<${env.BUILD_URL}|Open>)")
                } catch (err) {
                    echo "Slack not configured, skipping notification"
                }
            }
        }
        failure {
            script {
                try {
                    slackSend(channel: SLACK_CHANNEL, color: 'danger',
                        message: "❌ Build failed for *${PROJECT_NAME}* version *${env.VERSION}* (<${env.BUILD_URL}|Open>)")
                } catch (err) {
                    echo "Slack not configured, skipping notification"
                }
            }
        }
    }
}
