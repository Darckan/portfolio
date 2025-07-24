pipeline {
  agent any

  environment {
    SSH_USER = 'user'
    SSH_HOST = credentials('server-ip')
    REMOTE_DIR = '/home/user/project'
    CLUSTER_NAME = 'devops-cluster'
    NAMESPACE = 'dev'
    MAX_RETRIES = 10
    INTERVAL = 10
    // Puedes tener múltiples URLs separados por coma si lo deseas
    HEALTHCHECK_URLS = 'http://localhost/api/test,http://localhost' 
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

          ssh -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST bash -c "''
            set -e
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
          ''"
          '''
        }
      }
    }

    stage('Healthcheck remoto') {
      steps {
        sshagent (credentials: ['server-ssh-key']) {
          script {
            echo "🔍 Verificando salud remota de todos los servicios..."
            def urls = HEALTHCHECK_URLS.split(',')

            for (url in urls) {
              def success = false

              for (int i = 0; i < MAX_RETRIES.toInteger(); i++) {
                def code = sh(
                  script: """ssh -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST "curl -sf -o /dev/null -w '%{http_code}' $url" """,
                  returnStdout: true
                ).trim()

                if (code == '200') {
                  echo "✅ Servicio saludable (${url})"
                  success = true
                  break
                } else {
                  echo "❌ Intento #$i: $url → HTTP $code"
                  sleep(INTERVAL.toInteger())
                }
              }

              if (!success) {
                error("⛔ Healthcheck fallido para ${url}. Rollback necesario.")
              }
            }
          }
        }
      }
    }

    stage('Finalizar') {
      steps {
        echo "🎉 Todos los servicios verificados correctamente en Kubernetes."
      }
    }
  }

  post {
    failure {
      echo "🚨 Fallo detectado. Ejecutando rollback remoto..."

      sshagent (credentials: ['server-ssh-key']) {
        sh '''
        ssh -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST bash -c "''
          echo ⏪ Iniciando rollback completo en namespace $NAMESPACE...

          for dep in backend frontend ingress mysql; do
            echo 🔄 Rollback de $dep...
            if kubectl get deployment $dep -n $NAMESPACE > /dev/null 2>&1; then
              kubectl rollout undo deployment/$dep -n $NAMESPACE || echo ⚠️ Fallo rollback $dep
              kubectl rollout status deployment/$dep -n $NAMESPACE || true
            else
              echo ⚠️ Deployment $dep no existe en $NAMESPACE
            fi
          done
        ''"
        '''
      }
    }
    success {
      echo "✅ Despliegue exitoso. No fue necesario hacer rollback."
    }
  }
}
