#!/usr/bin/env bash
# Convenience port-forwards for the demo (run each in its own terminal, or background them).
set -euo pipefail
kubectl -n argocd port-forward svc/argocd-server 8081:443 &
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 &
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090 &
echo "ArgoCD https://localhost:8081  (user admin, pass: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "Grafana http://localhost:3000  Prometheus http://localhost:9090"
wait
