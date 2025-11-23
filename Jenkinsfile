pipeline {
    agent any
    tools {
        jdk 'JDK-21.0.8+9'
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
        
    }
}
