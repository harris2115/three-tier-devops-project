
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        DOCKERHUB_NAMESPACE = 'harris2115'
        EC2_HOST = '32.236.184.233'
        DEPLOY_DIR = '/home/ubuntu/three-tier-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Images') {
            steps {
                sh '''
                    docker build --pull \
                      -t ${DOCKERHUB_NAMESPACE}/three-tier-backend:${IMAGE_TAG} \
                      -t ${DOCKERHUB_NAMESPACE}/three-tier-backend:latest \
                      ./backend

                    docker build --pull \
                      --build-arg REACT_APP_API_BASE_URL= \
                      -t ${DOCKERHUB_NAMESPACE}/three-tier-frontend:${IMAGE_TAG} \
                      -t ${DOCKERHUB_NAMESPACE}/three-tier-frontend:latest \
                      ./frontend
                '''
            }
        }

        stage('Push Images to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        printf '%s' "$DOCKERHUB_TOKEN" | \
                          docker login -u "$DOCKERHUB_USER" --password-stdin

                        docker push ${DOCKERHUB_NAMESPACE}/three-tier-backend:${IMAGE_TAG}
                        docker push ${DOCKERHUB_NAMESPACE}/three-tier-backend:latest

                        docker push ${DOCKERHUB_NAMESPACE}/three-tier-frontend:${IMAGE_TAG}
                        docker push ${DOCKERHUB_NAMESPACE}/three-tier-frontend:latest

                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to AWS EC2') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'EC2_SSH_KEY',
                        usernameVariable: 'EC2_USER'
                    )
                ]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=accept-new \
                            -o BatchMode=yes \
                            -i "$EC2_SSH_KEY" \
                            "$EC2_USER@$EC2_HOST" \
                            "IMAGE_TAG='$IMAGE_TAG' bash -s" <<'REMOTE'

                        set -eu

                        cd /home/ubuntu/three-tier-app

                        sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=${IMAGE_TAG}/" .env

                        docker compose --env-file .env \
                            -f docker-compose.prod.yaml pull

                        docker compose --env-file .env \
                            -f docker-compose.prod.yaml up -d --remove-orphans

                        docker compose --env-file .env \
                            -f docker-compose.prod.yaml ps

                        for attempt in $(seq 1 12); do
                            if curl -fsS http://localhost/health >/dev/null; then
                                echo "Application health check successful"
                                exit 0
                            fi
                            echo "Waiting for application..."
                            sleep 5
                        done

                        echo "Application health check failed"
                        exit 1
REMOTE
                    '''
                }
            }
        }
    }

    post {
        always {
            echo 'Jenkins pipeline execution finished.'
        }

        success {
            echo 'Three-tier application deployed successfully!'
        }

        failure {
            echo 'Pipeline failed. Please inspect the stage logs.'
        }
    }
}
