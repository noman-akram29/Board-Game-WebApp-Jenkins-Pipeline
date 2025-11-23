pipeline {
    agent any

    stages {
        stage('Workspace Cleanup') {
            steps { cleanWs() }
        }

        stage('Checkout from SCM') {
            steps {
                git branch: 'main', credentialsId: 'Github-Token-for-Jenkins', url: 'https://github.com/noman-akram29/Board-Game-WebApp-Jenkins-Pipeline.git'
            }
        }
    }
}
