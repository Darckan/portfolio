#!/bin/bash

set -e

# CONFIGURACIÓN
CLUSTER_NAME="devops-cluster"
INGRESS_MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.5/deploy/static/provider/kind/deploy.yaml"
KIND_CONFIG="infra/k8s/kind-config.yaml"

echo "🔍 Verificando que Docker esté ejecutándose..."
if ! systemctl is-active --quiet docker; then
  echo "❌ Docker no está corriendo. Por favor, inícialo con: sudo systemctl start docker"
  exit 1
fi
echo "✅ Docker está corriendo."

# Verificar si el cluster Kind ya existe
echo "🔍 Verificando existencia del cluster Kind..."
if ! kind get clusters | grep -q "$CLUSTER_NAME"; then
  echo "🚀 Creando cluster Kind llamado $CLUSTER_NAME..."
  kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
else
  echo "ℹ️ Cluster $CLUSTER_NAME ya existe."
fi

# Construcción de imágenes locales
echo "🔨 Construyendo imágenes Docker..."

echo "🔧 backend:dev..."
docker build -t backend:dev ./backend

echo "🔧 frontend:dev..."
docker build -t frontend:dev ./frontend

# Cargar imágenes al cluster Kind
echo "📦 Cargando imágenes al cluster Kind..."
kind load docker-image backend:dev --name "$CLUSTER_NAME"
kind load docker-image frontend:dev --name "$CLUSTER_NAME"

# Esperar que el nodo esté Ready
echo "⏳ Esperando a que el nodo esté Ready..."
timeout=60
elapsed=0
while true; do
  if kubectl get nodes 2>/dev/null | grep -q " Ready "; then
    echo "✅ Nodo Ready."
    break
  fi
  sleep 5
  elapsed=$((elapsed + 5))
  if [ "$elapsed" -ge "$timeout" ]; then
    echo "❌ Nodo no está Ready después de $timeout segundos."
    exit 1
  fi
done

# Etiquetar nodo para Ingress
echo "🏷️ Etiquetando nodo con ingress-ready=true..."
kubectl label node "${CLUSTER_NAME}-control-plane" ingress-ready=true --overwrite || true

# Instalar Ingress Controller si no existe
echo "🔍 Verificando si Ingress Controller ya está desplegado..."
if ! kubectl get ns ingress-nginx >/dev/null 2>&1; then
  echo "🚀 Instalando Ingress Controller..."
  kubectl apply -f "$INGRESS_MANIFEST_URL"

  echo "⏳ Esperando a que el Ingress Controller esté listo..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=Ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=180s
else
  echo "✅ Ingress Controller ya desplegado."
fi

# Esperar a que Kubernetes responda
echo "🔄 Esperando que Kubernetes responda..."
max_wait=180
elapsed=0
until kubectl get nodes &>/dev/null; do
  if [ "$elapsed" -ge "$max_wait" ]; then
    echo "❌ Timeout esperando a que Kubernetes esté listo."
    exit 1
  fi
  sleep 3
  elapsed=$((elapsed + 3))
done
echo "✅ Kubernetes responde correctamente."

# Aplicar recursos
echo "📁 Aplicando recursos..."
kubectl apply -f infra/k8s/namespace.yaml
kubectl apply -f infra/k8s/mysql/
kubectl apply -f infra/k8s/backend/
kubectl apply -f infra/k8s/frontend/
kubectl apply -f infra/k8s/ingress/

echo "✅ Todos los recursos aplicados correctamente."
echo "🌐 Puedes acceder al entorno DevOps desde http://localhost (si está mapeado)."

