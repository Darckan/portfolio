pipeline {
  agent any

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['staging', 'prod'], description: 'Selecciona el entorno')
  }

  environment {
    SSH_USER = 'user'
    SSH_HOST = credentials('server-ip')
    REMOTE_DIR = '/home/user/project'
    CHART_NAME = 'microplatform'
    MAX_RETRIES = 10
    INTERVAL = 10
    HEALTHCHECK_URLS = 'http://localhost/api/test,http://localhost'
    LOAD_TEST_URL = 'http://localhost'
    LOAD_TEST_REQUESTS = 500
    LOAD_TEST_CONCURRENCY = 50
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Despliegue remoto con Helm') {
      steps {
        sshagent (credentials: ['server-ssh-key']) {
          sh '''
          echo "🚀 Desplegando entorno ${ENVIRONMENT}..."

          ssh -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST bash -c "'
            set -e
            cd $REMOTE_DIR

            echo 🔨 Build imágenes Docker...
            docker build -t backend:${ENVIRONMENT} ./backend
            docker build -t frontend:${ENVIRONMENT} ./frontend

            echo 📦 Cargando imágenes a Kind...
            kind load docker-image backend:${ENVIRONMENT} --name devops-cluster
            kind load docker-image frontend:${ENVIRONMENT} --name devops-cluster

            echo 📁 Desplegando con Helm...
            cd infra/microplatform

            kubectl get ns ${ENVIRONMENT} || kubectl create ns ${ENVIRONMENT}

            if helm status ${CHART_NAME}-${ENVIRONMENT} -n ${ENVIRONMENT} > /dev/null 2>&1; then
              echo "🔄 Actualizando release..."
              helm upgrade ${CHART_NAME}-${ENVIRONMENT} . -n ${ENVIRONMENT} -f values-${ENVIRONMENT}.yaml
            else
              echo "🚀 Instalando nuevo release..."
              helm install ${CHART_NAME}-${ENVIRONMENT} . -n ${ENVIRONMENT} -f values-${ENVIRONMENT}.yaml
            fi
          '"
          '''
        }
      }
    }

    stage('Healthcheck') {
      steps {
        sshagent (credentials: ['server-ssh-key']) {
          script {
            def urls = HEALTHCHECK_URLS.split(',')
            for (url in urls) {
              def success = false
              echo "🔍 Probing ${url}"
              for (int i = 0; i < MAX_RETRIES.toInteger(); i++) {
                def output = sh(
                  script: """ssh -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST "curl -s -o /dev/null -w '%{http_code}' $url || echo 000" """,
                  returnStdout: true
                ).trim()

                if (output == '200') {
                  echo "✅ ${url} respondió 200 OK"
                  success = true
                  break
                } else {
                  echo "⏱️ Intento ${i + 1}/${MAX_RETRIES}: HTTP $output"
                  sleep(INTERVAL.toInteger())
                }
              }
              if (!success) {
                error("❌ Healthcheck fallido para ${url}")
              }
            }
          }
        }
      }
    }

    stage('Test de carga') {
      steps {
        sshagent (credentials: ['server-ssh-key']) {
          sh '''
          ssh -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST bash -c "'
            if ! command -v hey >/dev/null 2>&1; then
              echo 📦 Instalando hey...
              curl -L https://github.com/rakyll/hey/releases/download/v0.1.4/hey_linux_amd64 -o /usr/local/bin/hey
              chmod +x /usr/local/bin/hey
            fi
            echo 💥 Ejecutando hey...
            hey -n $LOAD_TEST_REQUESTS -c $LOAD_TEST_CONCURRENCY $LOAD_TEST_URL
          '"
          '''
        }
      }
    }

    stage('Finalizar') {
      steps {
        echo "🎯 Despliegue y validación completados."
      }
    }
  }

  post {
    failure {
      echo "🧨 Falló algo. Iniciando rollback..."
      sshagent (credentials: ['server-ssh-key']) {
        sh '''
        ssh -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST bash -c "'
          for dep in backend frontend mysql; do
            echo 🔄 Rollback de $dep en $ENVIRONMENT...
            if kubectl get deployment $dep -n $ENVIRONMENT > /dev/null 2>&1; then
              kubectl rollout undo deployment/$dep -n $ENVIRONMENT || echo ⚠️ Fallo rollback $dep
              kubectl rollout status deployment/$dep -n $ENVIRONMENT --timeout=60s || true
            fi
          done
        '"
        '''
      }
    }
    success {
      echo "✅ Jenkins finalizó con éxito."
    }
  }
}
