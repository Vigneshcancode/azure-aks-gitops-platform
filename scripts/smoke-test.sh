#!/usr/bin/env bash
# Quick end-to-end check of the deployed platform. Run after ArgoCD has synced.
set -euo pipefail

PASS=0; FAIL=0
check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $name"; PASS=$((PASS+1)); else echo "FAIL  $name"; FAIL=$((FAIL+1)); fi
}

app_healthy() {
  [ "$(kubectl -n argocd get app "$1" -o jsonpath='{.status.health.status}')" = "Healthy" ] &&
  [ "$(kubectl -n argocd get app "$1" -o jsonpath='{.status.sync.status}')" = "Synced" ]
}

api_ok() {
  kubectl -n hello-api port-forward svc/hello-api 18080:80 >/dev/null 2>&1 &
  local pf=$!
  sleep 4
  local rc=0
  curl -fsS localhost:18080/ | grep -q '"service":"hello-api"' || rc=1
  kill "$pf" 2>/dev/null || true
  return "$rc"
}

secret_mounted() {
  kubectl -n hello-api port-forward svc/hello-api 18081:80 >/dev/null 2>&1 &
  local pf=$!
  sleep 4
  local rc=0
  curl -fsS localhost:18081/secret-check | grep -q '"secret_mounted":true' || rc=1
  kill "$pf" 2>/dev/null || true
  return "$rc"
}

check "ArgoCD app root is Synced/Healthy"                  app_healthy root
check "ArgoCD app kube-prometheus-stack is Synced/Healthy"  app_healthy kube-prometheus-stack
check "ArgoCD app hello-api is Synced/Healthy"              app_healthy hello-api
check "hello-api answers on /"                              api_ok
check "Key Vault secret is mounted in the pod"              secret_mounted
check "PrometheusRule exists"                               kubectl -n hello-api get prometheusrule hello-api
check "ServiceMonitor exists"                               kubectl -n hello-api get servicemonitor hello-api

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
