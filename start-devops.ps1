# CONFIGURACIÓN
$ClusterName = "devops-cluster"
$IngressManifestUrl = "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.5/deploy/static/provider/kind/deploy.yaml"
$KindConfig = "infra/k8s/kind-config.yaml"

Write-Host "Verificando que Docker Desktop esté ejecutándose..."
$dockerRunning = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
if (-not $dockerRunning) {
    Write-Host "Docker Desktop no está corriendo. Por favor, inícialo manualmente y vuelve a ejecutar este script."
    Pause
    exit 1
}
Write-Host "Docker Desktop está corriendo."

# Verificar si el cluster Kind ya existe
Write-Host "Verificando existencia del cluster Kind..."
$clusters = kind get clusters
if ($clusters -notcontains $ClusterName) {
    Write-Host "Creando cluster Kind llamado $ClusterName..."
    kind create cluster --name $ClusterName --config $KindConfig
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error creando cluster Kind. Revisa los logs."
        Pause
        exit 1
    }
} else {
    Write-Host "Cluster $ClusterName ya existe."
}

# Construcción de imágenes locales
Write-Host "Construyendo imágenes Docker..."

Write-Host "backend:dev..."
docker build -t backend:dev ./backend
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error al construir la imagen del backend."
    Pause
    exit 1
}

Write-Host "frontend:dev..."
docker build -t frontend:dev ./frontend
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error al construir la imagen del frontend."
    Pause
    exit 1
}

# Cargar imágenes al cluster Kind
kind load docker-image backend:dev --name $ClusterName
kind load docker-image frontend:dev --name $ClusterName

# Esperar que el nodo esté Ready (máx 60s)
Write-Host "Esperando que el nodo del cluster esté Ready..."
$timeout = 60
$elapsed = 0
do {
    Start-Sleep -Seconds 5
    $elapsed += 5
    $ready = kubectl get nodes --no-headers | Select-String " Ready "
} until ($ready -or $elapsed -ge $timeout)

if (-not $ready) {
    Write-Host "Nodo no está Ready después de 60 segundos."
    Pause
    exit 1
}

# Etiquetar nodo para Ingress
Write-Host "Etiquetando el nodo con ingress-ready=true..."
kubectl label node "$ClusterName-control-plane" ingress-ready=true --overwrite

# Verificar si ingress-nginx ya está instalado
Write-Host "Verificando si NGINX Ingress ya está desplegado..."
$ingressExists = kubectl get ns ingress-nginx -o name -ErrorAction SilentlyContinue
if (-not $ingressExists) {
    Write-Host "Instalando Ingress Controller..."
    kubectl apply -f $IngressManifestUrl

    Write-Host "Esperando que el Ingress Controller este listo (max 180s)..."
    kubectl wait --namespace ingress-nginx --for=condition=Ready pod --selector=app.kubernetes.io/component=controller --timeout=180s
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Timeout esperando al Ingress Controller. Revisa el estado."
        Pause
        exit 1
    }
} else {
    Write-Host "Ingress Controller ya está desplegado."
}



# Esperar a que el servidor de Kubernetes responda
$maxWait = 180
$elapsed = 0
while ($true) {
    try {
        kubectl get nodes > $null 2>&1
        break
    } catch {
        if ($elapsed -ge $maxWait) {
            Write-Host "Timeout esperando a que Kubernetes esté listo."
            exit 1
        }
        Start-Sleep -Seconds 3
        $elapsed += 3
    }
}
Write-Host "Kubernetes responde correctamente."


# Crear Namespace
kubectl apply -f infra/k8s/namespace.yaml

# Aplicar recursos
kubectl apply -f infra/k8s/mysql/
kubectl apply -f infra/k8s/backend/
kubectl apply -f infra/k8s/frontend/
kubectl apply -f infra/k8s/ingress/

Write-Host "Todos los recursos aplicados correctamente."

# Abrir navegador
Write-Host "Abriendo el navegador en http://localhost ..."
Start-Process "http://localhost"

Write-Host "Entorno DevOps iniciado correctamente."
Pause
