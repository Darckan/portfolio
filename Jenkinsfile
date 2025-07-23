pipeline {
    agent any

    environment {
        BACKUP_DIR = "/home/devops/backups"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Backup Database') {
            steps {
                withCredentials([
                    sshUserPrivateKey(credentialsId: 'server-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
                    string(credentialsId: 'server-ip', variable: 'SSH_HOST')
                ]) {
                    sh '''
                    echo "📦 Backing up database..."
                    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST "
                        mkdir -p $BACKUP_DIR &&
                        docker exec mysql mysqldump -uroot -p$DB_PASS --all-databases > $BACKUP_DIR/backup-$(date +%F-%H%M).sql
                    "
                    '''
                }
            }
        }

        stage('Deploy to Green') {
            steps {
                withCredentials([
                    sshUserPrivateKey(credentialsId: 'server-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
                    string(credentialsId: 'server-ip', variable: 'SSH_HOST')
                ]) {
                    sh '''
                    echo "🚀 Deploying to Green..."
                    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST '
                        # Clone repo if it doesn’t exist
                        if [ ! -d /home/$SSH_USER/project-green ]; then
                            git clone https://github.com/Darckan/portfolio.git /home/$SSH_USER/project-green
                        fi
                        cd /home/$SSH_USER/project-green &&
                        git reset --hard &&
                        git pull origin main &&
                        docker compose pull &&
                        docker compose up -d --remove-orphans
                    '
                    '''
                }
            }
        }

        stage('Health Check') {
            steps {
                withCredentials([
                    sshUserPrivateKey(credentialsId: 'server-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
                    string(credentialsId: 'server-ip', variable: 'SSH_HOST')
                ]) {
                    script {
                        def result = sh(script: """
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST \
                            'curl -fsS http://localhost || exit 1'
                        """, returnStatus: true)

                        if (result != 0) {
                            error("❌ Health check failed. Rolling back...")
                        }
                    }
                }
            }
        }

        stage('Switch Proxy') {
            steps {
                withCredentials([
                    sshUserPrivateKey(credentialsId: 'server-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
                    string(credentialsId: 'server-ip', variable: 'SSH_HOST')
                ]) {
                    sh '''
                    echo "🔁 Switching NGINX proxy to Green..."
                    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST '
                        docker exec nginx sh -c "sed -i s/blue/green/g /etc/nginx/nginx.conf && nginx -s reload"
                    '
                    '''
                }
            }
        }

        stage('Rollback') {
            when {
                expression { currentBuild.result == 'FAILURE' }
            }
            steps {
                withCredentials([
                    sshUserPrivateKey(credentialsId: 'server-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
                    string(credentialsId: 'server-ip', variable: 'SSH_HOST')
                ]) {
                    sh '''
                    echo "⏪ Rolling back to Blue..."
                    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST '
                        cd /home/$SSH_USER/project-blue &&
                        docker compose up -d --remove-orphans &&
                        docker exec nginx sh -c "sed -i s/green/blue/g /etc/nginx/nginx.conf && nginx -s reload"
                    '
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ Deployment successful. Green environment is live."
        }
        failure {
            echo "⚠️ Deployment failed. Rollback attempted."
        }
    }
}
