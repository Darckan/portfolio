pipeline {
    agent any

    environment {
        BACKUP_DIR = "/home/user/backups"
        DB_PASS = credentials('mysql-root-pass')
         SSH_IP = credentials('server-ip')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Backup Database') {
            steps {
                sshagent (credentials: ['server-ssh-key']) {
                    sh '''
                    echo "📦 Backing up database..."
                    ssh -o StrictHostKeyChecking=no user@$SSH_IP "
                        mkdir -p $BACKUP_DIR &&
                        docker exec mysql mysqldump -uroot -p$DB_PASS --all-databases > $BACKUP_DIR/backup-$(date +%F-%H%M).sql
                    "
                    '''
                }
            }
        }

        stage('Deploy to Green') {
            steps {
                sshagent (credentials: ['server-ssh-key']) {
                    sh '''
                    echo "🚀 Deploying to Green..."
                    ssh -o StrictHostKeyChecking=no user@$SSH_IP '
                        if [ ! -d /home/user/project-green ]; then
                            git clone https://github.com/Darckan/portfolio.git /home/user/project-green
                        fi
                        cd /home/user/project-green &&
                        git reset --hard &&
                        git pull origin master &&
                        docker-compose pull &&
                        docker-compose up -d --remove-orphans
                    '
                    '''
                }
            }
        }

        stage('Health Check') {
            steps {
                sshagent (credentials: ['server-ssh-key']) {
                    script {
                        def result = sh(script: """
                            ssh -o StrictHostKeyChecking=no user@$SSH_IP \
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
                sshagent (credentials: ['server-ssh-key']) {
                    sh '''
                    echo "🔁 Switching NGINX proxy to Green..."
                    ssh -o StrictHostKeyChecking=no user@$SSH_IP '
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
                sshagent (credentials: ['server-ssh-key']) {
                    sh '''
                    echo "⏪ Rolling back to Blue..."
                    ssh -o StrictHostKeyChecking=no user@$SSH_IP '
                        cd /home/user/project-blue &&
                        docker-compose up -d --remove-orphans &&
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
