# Project 3 (p3): GitOps Deployment with Argo CD

## Overview

**Part 3** moves beyond manual Kubernetes deployment to **GitOps** – a paradigm where Git becomes the single source of truth for your infrastructure and application configuration. Instead of manually running `kubectl apply`, you define everything in a Git repository, and a GitOps controller (Argo CD) automatically syncs your cluster to match that state.

This project demonstrates:
1. **Local k3d cluster** with port 8888→80 mapping for external access
2. **Argo CD installation** in a dedicated namespace
3. **Application deployment** managed by Argo CD pulling from a remote GitHub repository
4. **Ingress routing** to expose the application via HTTP
5. **GitOps workflow** – infrastructure as code synchronized continuously

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Your Host Machine (localhost:8888)         │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ↓ (port 8888→80@loadbalancer)
┌─────────────────────────────────────────────────────────┐
│                      k3d Cluster                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │     Traefik Ingress (Built-in K3s default)       │   │
│  │  Port 80 receives external traffic, routes       │   │
│  │  based on HTTP host/path rules                   │   │
│  └────────────────┬─────────────────────────────────┘   │
│                   │                                       │
│      ┌────────────┴────────────┐                         │
│      ↓                         ↓                         │
│  ┌─────────────┐           ┌──────────────────┐         │
│  │  dev         │           │  argocd           │        │
│  │  namespace   │           │  namespace        │        │
│  ├─────────────┤           ├──────────────────┤         │
│  │ smokeybull- │           │ Argo CD Server    │         │
│  │ app Service │           │ (GitOps engine)   │         │
│  │ :80         │           │                   │         │
│  │    ↓        │           │ Syncs remote      │         │
│  │ Deployment  │           │ GitHub repo to    │         │
│  │ smokeybull- │           │ dev namespace     │         │
│  │ app         │           │                   │         │
│  │   ↓         │           │                   │         │
│  │ Pod:3000    │           └──────────────────┘         │
│  │             │                                         │
│  └─────────────┘                                         │
│                                                          │
└──────────────────────────────────────────────────────────┘
                       ↑
                       │ (Source of truth)
             ┌─────────┴──────────┐
             │ GitHub Repository  │
             │ sixie17/inception- │
             │ of-things-ArgoCD   │
             │ /infra folder:     │
             │ • deployment.yaml  │
             │ • service.yaml     │
             │ • (ingress.yaml)   │
             └────────────────────┘
```

---

## Key Concepts

### 1. GitOps

**GitOps** is a set of practices that use Git as the single source of truth for declarative infrastructure and application code:

- **Declarative**: You describe the *desired state* (not the steps to achieve it)
- **Versioned**: All changes are committed to Git with history and auditability
- **Automated**: A controller continuously reconciles cluster state to match Git
- **Safe**: Pull requests, reviews, and rollbacks are built in

**Benefits:**
- Single source of truth (no manual `kubectl apply` drifts)
- Audit trail (every change in Git history)
- Rollback capability (just revert a commit, controller syncs back)
- Infrastructure as Code (treat config like application code)

**Reference:** [Weaveworks GitOps](https://www.weave.works/blog/gitops-operations-by-pull-request)

### 2. Argo CD

**Argo CD** is a declarative GitOps continuous delivery tool for Kubernetes:

- Monitors a Git repository for changes
- Automatically syncs the cluster to match the Git state
- Provides a UI to view app status, manual sync, and rollbacks
- Supports multiple clusters and deployment strategies

**How it works:**
1. You create an `Application` resource that points to a Git repo and destination cluster
2. Argo CD watches that repo for changes
3. When Git changes, Argo CD applies manifests to the cluster
4. Argo CD continuously reconciles (watches cluster and syncs back if drift detected)

**Reference:** [Argo CD Official Docs](https://argo-cd.readthedocs.io/)

### 3. k3d

**k3d** is a lightweight tool that runs [K3s](https://k3s.io/) (lightweight Kubernetes) inside Docker containers. For development and testing:

- Creates a full Kubernetes cluster in seconds
- Runs entirely in Docker (no VMs needed)
- Includes Traefik ingress controller by default
- Fast, minimal resource footprint

**In this project:**
```bash
k3d cluster create p3 -p "8888:80@loadbalancer"
```
Creates a cluster named `p3` and maps host port 8888 to the ingress (Traefik) on port 80 inside the cluster.

**Reference:** [k3d GitHub](https://github.com/k3d-io/k3d)

### 4. Traefik Ingress

**Ingress** is a Kubernetes resource that manages external HTTP/HTTPS access. **Traefik** is an ingress controller that watches Ingress resources and configures routing.

In this project:
- Ingress rule routes requests to `smokeybull-app` Service on port 80
- Service forwards traffic to pod on port 3000
- Traefik listens on port 80 (mapped from host 8888)

**Reference:** [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)

### 5. Namespaces

Kubernetes **Namespaces** are virtual clusters within a cluster, providing logical isolation:

- `argocd`: Holds Argo CD controller, server, and supporting components
- `dev`: Application workloads (deployment, service, ingress)
- `kube-system`: Core system components (Traefik, metrics-server, etc.)

Each namespace can have its own RBAC policies, resource quotas, and network policies.

**Reference:** [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)

---

## File Structure

```
p3/
├── README.md                      # This file
├── scripts/
│   ├── install.sh                 # Installs dependencies (docker, kubectl, k3d)
│   └── run-cluster.sh             # Creates cluster, installs Argo CD, applies config
└── confs/
    ├── argocd.yaml                # Argo CD Application resource
    └── ingress.yaml               # HTTP routing rules for dev namespace
```

---

## Setup & Deployment

### Step 1: Install Dependencies

```bash
cd p3
bash scripts/install.sh
```

Installs:
- Docker (if not present)
- kubectl (Kubernetes CLI)
- k3d (k3s in Docker)

### Step 2: Create Cluster and Deploy Argo CD

```bash
bash scripts/run-cluster.sh
```

This script:
1. Creates a k3d cluster named `p3` with port mapping 8888:80
2. Creates `argocd` and `dev` namespaces
3. Installs Argo CD from official manifests (server-side apply)
4. Patches Argo CD config to enable insecure (HTTP) mode for local testing
5. Applies the Argo CD Application resource (syncs GitHub repo)
6. Applies the Ingress resource for routing
7. Prints Argo CD credentials and starts port-forward to the UI

### Step 3: Access Argo CD UI

Once the script finishes:

```
http://localhost:8080
```

**Credentials printed in console:**
- Username: `admin`
- Password: (printed in output, also retrievable via):
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d; echo
  ```

In the UI, you'll see:
- Application: `argocd-app` (status: Synced or OutOfSync)
- Current deployment state from GitHub
- Manual sync button
- Pod/service details

### Step 4: Access Your Application

```bash
curl http://localhost:8888
```

Should return the response from `sixiecow/inception-of-things:v2` image listening on port 3000.

---

## Configuration Files Explained

### `confs/argocd.yaml` – Argo CD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/sixie17/inception-of-things-ArgoCD'
    targetRevision: main
    path: infra
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Key fields:**
- `source.repoURL`: GitHub repository containing Kubernetes manifests
- `source.path`: Folder in the repo to sync (`infra/`)
- `destination.server`: Kubernetes cluster API (in-cluster: `kubernetes.default.svc`)
- `destination.namespace`: Deploy to `dev` namespace
- `syncPolicy.automated.prune`: Delete resources on cluster if removed from Git
- `syncPolicy.automated.selfHeal`: Sync if cluster drifts from Git state

**What syncs from the repo:**
- `infra/deployment.yaml` – App Pod template
- `infra/service.yaml` – Service exposing the app
- Optional `infra/ingress.yaml` – HTTP routing (if present in remote repo)

### `confs/ingress.yaml` – HTTP Routing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: smokeybull-app-ingress
  namespace: dev
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: smokeybull-app
            port:
              number: 80
```

**What this does:**
- Tells Traefik to route all HTTP requests (`/`) to `smokeybull-app` Service on port 80
- Service (from GitHub repo) then forwards to pod port 3000
- Annotations configure Traefik to use the `web` entrypoint (HTTP port 80)

---

## Remote Repository Structure

The Argo CD Application syncs from: https://github.com/sixie17/inception-of-things-ArgoCD/tree/main/infra

**Typical structure:**
```
infra/
├── deployment.yaml       # Defines Pods
├── service.yaml          # Exposes Pods inside/outside cluster
└── ingress.yaml (optional) # HTTP routing rules
```

### Deployment (from remote repo)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: smokeybull-app
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: smokeybull-app
  template:
    metadata:
      labels:
        app: smokeybull-app
    spec:
      containers:
      - name: app-container
        image: sixiecow/inception-of-things:v2
        ports:
        - containerPort: 3000
```

- Deploys 1 replica of the Node.js app image
- App listens on port 3000 inside the container
- Labels pods with `app: smokeybull-app` for service to find them

### Service (from remote repo)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: smokeybull-app
  namespace: dev
spec:
  selector:
    app: smokeybull-app
  ports:
  - name: http
    port: 80
    targetPort: 3000
    protocol: TCP
  type: LoadBalancer
```

- Selects pods labeled `app: smokeybull-app`
- Exposes port 80 (standard HTTP)
- Forwards to pod port 3000
- Type `LoadBalancer` (in cloud, provisions external LB; in k3d, managed by local LB)

**Traffic flow:**
```
Host localhost:8888
  → k3d ingress port 80
    → Traefik routes to Service:80
      → Service forwards to Pod:3000
        → Node.js app responds
```

---

## How Argo CD Works (Reconciliation Loop)

```
1. You push a change to GitHub (e.g., update image tag in deployment.yaml)
   ↓
2. Argo CD polls the repo (or via webhook)
   ↓
3. Argo CD compares Git state vs. cluster state
   ↓
4. If different: Status shows "OutOfSync"
   ↓
5. Auto-sync enabled? → Argo CD applies manifests to cluster
   ↓
6. Cluster converges to Git state
   ↓
7. Status shows "Synced"
```

If someone manually edits cluster (e.g., `kubectl edit deployment`), Argo CD detects drift and re-applies Git state (self-healing).

---

## Common Tasks

### Check Argo CD Application Status

```bash
kubectl -n argocd get applications
kubectl -n argocd describe application argocd-app
```

### View Application Logs

```bash
# Argo CD server logs
kubectl -n argocd logs deployment/argocd-server

# Application pod logs
kubectl -n dev logs -l app=smokeybull-app
```

### Manually Sync (if auto-sync disabled)

Via CLI:
```bash
argocd app sync argocd-app
```

Or via UI: Click "Sync" button in Argo CD UI.

### Roll Back to Previous Git Commit

```bash
# In your GitHub repo, revert the commit
git revert <commit-hash>
git push

# Argo CD will detect and sync back to old state
```

### Update Application (Push New Version)

1. Update `infra/deployment.yaml` in your GitHub repo (e.g., new image tag)
2. Commit and push to `main` branch
3. Argo CD detects in ~3 mins (default poll interval) or sooner if webhook configured
4. Apply new manifest to cluster, trigger pod restart with new image

### Monitor Real-Time Changes

```bash
# Watch cluster resources in dev namespace
kubectl -n dev get pods,svc,ingress -w

# Watch Argo CD applications
kubectl -n argocd get applications -w
```

---

## Troubleshooting

### Pod stuck in ErrImagePull

```bash
kubectl -n dev describe pod <pod-name>
```

Check for:
- Image name typo
- Image tag doesn't exist
- Private registry (need imagePullSecret)
- Network/rate-limit issues

**Solution:** Fix image in `infra/deployment.yaml`, commit, push, let Argo CD sync.

### Ingress returns 404

```bash
kubectl -n dev get ingress
kubectl -n dev describe ingress smokeybull-app-ingress
kubectl -n dev get endpoints smokeybull-app
```

Check:
- Ingress rule syntax (host/path matches)
- Service port number matches ingress backend port
- Pod is actually running (endpoints not empty)

### Argo CD UI not accessible

```bash
# Port-forward already running?
kubectl -n argocd get pods | grep argocd-server
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

Then: `http://localhost:8080`

### Service not reachable

```bash
# Check if service has endpoints
kubectl -n dev get endpoints smokeybull-app

# Test from within cluster
kubectl -n dev run -it --rm debug --image=curlimages/curl --restart=Never \
  -- curl http://smokeybull-app:80
```

---

## Progression from p1 → p3

| Part | Focus | Key Tech |
|------|-------|----------|
| **p1** | Multi-node cluster basics | K3s, Vagrant, VMs |
| **p2** | Manual deployment, multi-app routing | Ingress, Labels, Selectors |
| **p3** | GitOps automation, continuous sync | Argo CD, Git as source of truth |

---

## References & Learning Resources

- **Argo CD Official** – https://argo-cd.readthedocs.io/
- **Kubernetes Concepts** – https://kubernetes.io/docs/concepts/
- **GitOps Best Practices** – https://www.weave.works/technologies/gitops/
- **K3s Lightweight Kubernetes** – https://k3s.io/
- **Traefik Ingress** – https://doc.traefik.io/traefik/
- **CNCF Landscape** – https://landscape.cncf.io/

---

## Project Summary

**p3** demonstrates how modern DevOps teams deploy applications: instead of manual `kubectl` commands, infrastructure and application configs live in Git. A GitOps controller (Argo CD) keeps the cluster in sync, enabling:

- **Reproducibility**: Same Git state → same cluster state (everywhere)
- **Safety**: PR approval before deployment
- **Auditability**: Every change tracked in Git history
- **Recovery**: Rollback by reverting commits
- **Scale**: Deploy to multiple clusters from one Git repo

This pattern is industry standard for cloud-native deployments.
