#!/bin/bash

#create the gitlab namespace, if it doesn't already exist
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

# Generate the root password ONCE — skip if it already exists
if ! kubectl -n gitlab get secret gitlab-root-password >/dev/null 2>&1; then
  kubectl -n gitlab create secret generic gitlab-root-password \
    --from-literal=password="$(openssl rand -base64 20)"
fi

# Deploy GitLab
kubectl apply -f confs/gitlab.yaml

echo "Waiting for GitLab to become ready (first boot can take 5-10+ minutes)..."
kubectl -n gitlab wait --for=condition=available deployment/gitlab --timeout=600s

# repoint Argo CD from GitHub to local GitLab
kubectl apply -f confs/argocd.yaml

# Ingress routing — app and GitLab both reachable via Host header on the same port 8888
kubectl apply -f confs/ingress.dev.yaml
kubectl apply -f confs/ingress.gitlab.yaml

# Print everything we need
echo ""
echo "===================== BONUS ====================="
echo "GitLab (root login):"
echo "  URL:      http://gitlab.localhost:8888"
echo "  Username: root"
echo "  Password: $(kubectl -n gitlab get secret gitlab-root-password -o jsonpath='{.data.password}' | base64 -d)"
echo ""
echo "App (now synced from local GitLab via Argo CD):"
echo "  URL:      http://localhost:8888"
echo ""
echo "Argo CD UI — use another terminal, then browse http://localhost:8080 :"
echo "  kubectl -n argocd port-forward svc/argocd-server 8080:80"
echo "Username: admin"
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "=========================================================="
