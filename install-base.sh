#!/bin/bash

export GLOO_VERSION="1.18.0-rc1"

# Use the GLOO_LICENSE_KEY environment variable if set, otherwise prompt the user
if [[ -z "$GLOO_LICENSE_KEY" ]]; then
  read -p "Please enter your Gloo license key: " LICENSE_KEY
else
  export LICENSE_KEY="$GLOO_LICENSE_KEY"
fi

# Exit immediately if a command exits with a non-zero status
set -e

#echo "### Adding Gloo EE Helm repository..."
#helm repo add gloo-ee-helm https://storage.googleapis.com/gloo-ee-helm
#helm repo update

echo "### Installing Gateway API CRDs..."
#kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
kubectl apply -k gwapi-crds/1.2.0

sleep 5

echo "### Installing Gloo Gateway..."
helm upgrade --install -n gloo-system \
gloo-gateway gloo-ee-helm/gloo-ee \
--create-namespace \
--version $GLOO_VERSION \
--set-string license_key=$LICENSE_KEY \
-f -<<EOF
gloo:
  kubeGateway:
    enabled: true
  gatewayProxies:
    gatewayProxy:
      disabled: true
  discovery:
    enabled: false
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
# disable everything else for a simple deployment
observability:
  enabled: false
prometheus:
  enabled: false
grafana:
  defaultInstallationEnabled: false
gateway-portal-web-server:
  enabled: false
EOF

echo "### Checking Gloo Gateway components..."
kubectl get pods -n gloo-system

kubectl wait deploy --all -n gloo-system \
    --for=condition=Available --timeout=120s

echo "### Installing AI Gateway..."
kubectl apply -f ai-gateway

echo "### Checking AI Gateway proxy components..."

sleep 5
kubectl wait deploy/gloo-proxy-ai-gateway -n gloo-system \
    --for=condition=Available --timeout=120s

echo "### Installing Ollama deployment..."
kubectl apply -f ollama-deploy

echo "### Checking Ollama deployment..."
kubectl wait deploy/ollama-qwen -n ollama \
    --for=condition=Available --timeout=600s

echo "### Setup complete!"
