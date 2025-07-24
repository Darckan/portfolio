pipeline {
  agent any

  environment {
    SSH_USER = 'user'
    SSH_HOST = credentials('server-ip')
    REMOTE_DIR = '/home/user/project'
    HEALTHCHECK_URL = 'http://localhost/api/test'
    CLUSTER_NAME = 'devops-cluster'
    BACKEND_DEPLOYMENT = 'backend'
    NAMESPACE = 'default'
    MAX_RETRIES = 10
    INTERVAL = 10
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Deploy en servidor remoto') {
      steps {
        sshagent (credentials: ['server-ssh-key']) {
          sh '''
          echo "📦 Ejecutando build y despliegue remoto..."

          ssh -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST bash -c "'
            cd $REMOTE_DIR

            echo 🔨 Construyendo imágenes Docker...
            docker build -t backend:dev ./backend
            docker build -t frontend:dev ./frontend

            echo 📦 Cargando imágenes a Kind...
            kind load docker-image backend:dev --name $CLUSTER_NAME
            kind load docker-image frontend:dev --name $CLUSTER_NAME

            echo 📁 Aplicando manifiestos Kubernetes...
            kubectl apply -f infra/k8s/namespace.yaml
            kubectl apply -f infra/k8s/mysql/
            kubectl apply -f infra/k8s/backend/
            kubectl apply -f infra/k8s/frontend/
            kubectl apply -f infra/k8s/ingress/
          '"
          '''
        }
      }
    }

    stage('Healthcheck remoto') {
      steps {
        sshagent (credentials: ['server-ssh-key']) {
          script {
            echo "🔍 Verificando salud del backend remoto..."

            def success = false

            for (int i = 0; i < MAX_RETRIES.toInteger(); i++) {
              def code = sh(
                script: """ssh -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST "curl -sf -o /dev/null -w '%{http_code}' $HEALTHCHECK_URL" """,
                returnStdout: true
              ).trim()

              if (code == '200') {
                echo "✅ Backend saludable (HTTP 200)"
                success = true
                break
              } else {
                echo "❌ Intento #$i: HTTP $code"
                sleep(INTERVAL.toInteger())
              }
            }

            if (!success) {
              error("⛔ Healthcheck fallido. Rollback necesario.")
            }
          }
        }
      }
    }

    stage('Finalizar') {
      steps {
        echo "🎉 Despliegue en Kubernetes verificado correctamente."
      }
    }
  }

  post {
    failure {
      echo "🚨 Fallo detectado. Ejecutando rollback remoto..."

      sshagent (credentials: ['server-ssh-key']) {
        sh '''
        ssh -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST bash -c "'
          echo ⏪ Rollback en curso...
          kubectl rollout undo deployment/$BACKEND_DEPLOYMENT -n $NAMESPACE || echo ⚠️ No se pudo hacer rollback
          kubectl rollout status deployment/$BACKEND_DEPLOYMENT -n $NAMESPACE || true
        '"
        '''
      }
    }
    success {
      echo "✅ Todo fue bien. No se necesitó rollback."
    }
  }
}
