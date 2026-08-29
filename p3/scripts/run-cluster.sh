k3d cluster create p3 -p "8888:80@loadbalancer"

kubectl config use-context k3d-p3

kubectl create namespace argocd
kubectl create namespace dev

kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD pods..."

kubectl -n argocd patch configmap argocd-cmd-params-cm --type merge \
  -p '{"data":{"server.insecure":"true"}}'
kubectl -n argocd rollout restart deployment argocd-server
kubectl -n argocd rollout status deployment argocd-server --timeout=300s

kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s


kubectl apply -f confs/argocd.yaml
kubectl apply -f confs/ingress.yaml

echo "ArgoCD credentials:"
echo "Username: admin"
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo)"

kubectl -n argocd port-forward svc/argocd-server 8080:80


