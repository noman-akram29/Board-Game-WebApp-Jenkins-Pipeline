pipeline {
    agent any
    tools {
        jdk 'JDK-17.0.9+9'
        maven 'Maven-3.9.11'
    }
    environment {
        SCANNER_HOME = tool 'SonarQube-Scanner-Tool'
    }
    stages {
        stage('Workspace Cleanup') {
            steps { cleanWs() }
        }

        stage('Checkout from SCM') {
            steps {
                git branch: 'main', credentialsId: 'Github-Token-for-Jenkins', url: 'https://github.com/noman-akram29/Board-Game-WebApp-Jenkins-Pipeline.git'
            }
        }
        stage('Maven Compile') { steps { sh 'mvn clean compile' } }
        stage('Maven Test')    { steps { sh 'mvn test' } }
        
        stage('File System Scan') {
            steps {
                sh "trivy fs --format table -o trivy-fs-report.html ."
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh '''
                        $SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectName=BoardGame \
                        -Dsonar.projectKey=BoardGame \
                        -Dsonar.java.binaries=.
                    '''
                }
            }
        }
        stage('Code Quality Gate') {
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'SonarQube-Token-for-Jenkins'
                }
            }
        }
        stage('Maven Build')    { steps { sh 'mvn package' } }

        stage('Publish to Nexus') {
            steps {
                withMaven(globalMavenSettingsConfig: 'Global-Config-Settings', jdk: 'JDK-17.0.9+9', maven: 'Maven-3.9.11', traceability: true) {
                    sh "mvn deploy"
                }
            }
        }
        stage('Build & Tag Docker Image') {
            steps {
                withDockerRegistry(credentialsId: 'DockerHub-Creds-for-Jenkins', toolName: 'Docker-Tool') {
                    sh "docker build -t nomanakram29/boardgame:latest ."
                }
            }
        }
        stage('Docker Image Scan') {
            steps {
                sh "trivy image --format table -o trivy-image-report.html nomanakram29/boardgame:latest"
            }
        }
        stage('Docker Push Image'){
            steps{
                withCredentials([string(credentialsId: 'DockerHub-Creds-for-Jenkins', toolName: 'Docker-Tool')]) {
                    // sh "docker login -u nomanakram29 -p ${dokcerHubPWD}"
                    sh "docker push nomanakram29/boardgame:latest"
                }
            }
        }
    }
}

