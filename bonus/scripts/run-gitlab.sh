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

# Ingress routing — app and GitLab both reachable via Host header on the same port 8888
kubectl apply -f confs/ingress.dev.yaml
kubectl apply -f confs/ingress.gitlab.yaml

GITLAB_PASSWORD=$(kubectl -n gitlab get secret gitlab-root-password -o jsonpath='{.data.password}' | base64 -d)
GITLAB_PASSWORD_URLENC=$(jq -rn --arg v "$GITLAB_PASSWORD" '$v|@uri')
REPO_URL="http://root:${GITLAB_PASSWORD_URLENC}@gitlab.localhost:8888/root/inception-of-things-argocd.git"

# Create the GitLab project 
kubectl -n gitlab exec deployment/gitlab -- gitlab-rails runner "
  user = User.find_by(username: 'root')
  project = Project.find_by_full_path('root/inception-of-things-argocd')
  if project.nil?
    project = ::Projects::CreateService.new(user, {
      name: 'inception-of-things-argocd',
      path: 'inception-of-things-argocd',
      visibility_level: Gitlab::VisibilityLevel::PUBLIC
    }).execute
    puts project.persisted? ? 'created' : 'FAILED: ' + project.errors.full_messages.join(', ')
  else
    puts 'already exists'
  end
"

# Push the starting app manifests, only if the repo is still empty
if ! git ls-remote --exit-code "$REPO_URL" main >/dev/null 2>&1; then
  echo "Repo is empty — pushing initial app manifests..."
  TMP_DIR=$(mktemp -d)
  cp -r gitlab-repo/infra "$TMP_DIR/"
  (
    cd "$TMP_DIR"
    git init -q
    git checkout -q -b main
    git add infra/
    git -c user.email="bonus@local" -c user.name="bonus-script" commit -q -m "Initial app manifests"
    git push -q "$REPO_URL" main
  )
  rm -rf "$TMP_DIR"
else
  echo "Repo already has content — leaving it as-is."
fi

# repoint Argo CD from GitHub to local GitLab
kubectl apply -f confs/argocd.yaml

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
