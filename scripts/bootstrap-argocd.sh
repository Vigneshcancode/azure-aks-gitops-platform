#!/usr/bin/env bash
# Installs ArgoCD on the cluster and hands control to the root app (GitOps takes over from here).
# Run after configure.sh output has been pushed to GitHub.
set -euo pipefail

ENVIRONMENT="${1:-dev}"
PROJECT="${PROJECT:-aksgitops}"
RG="rg-${PROJECT}-${ENVIRONMENT}"
AKS="aks-${PROJECT}-${ENVIRONMENT}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.13.3}"

cd "$(dirname "$0")/.."

if grep -q REPO_URL_PLACEHOLDER gitops/argocd/root-app.yaml; then
  echo "root-app.yaml still has the placeholder. Run scripts/configure.sh first and push." >&2
  exit 1
fi

az aks get-credentials -g "$RG" -n "$AKS" --overwrite-existing

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

kubectl apply -n argocd -f gitops/argocd/root-app.yaml

echo
echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo
echo "UI: kubectl -n argocd port-forward svc/argocd-server 8080:443  (https://localhost:8080, user: admin)"
