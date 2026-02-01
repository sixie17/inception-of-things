# Project 2 (p2): Multi-App Deployment with Host-Based Routing

## Architecture

### Traffic Flow
```
External Request → Ingress (Traefik) → Service → Pods (Deployments)
```

**Host-based routing** means traffic is routed to different applications based on the `Host` header:
- `Host: app1.com` → app1-service → app1 pods
- `Host: app2.com` → app2-service → app2 pods (3 replicas with load balancing)
- `Host: app3.com` → app3-service → app3 pods

### Components Deployed

#### 1. Deployments
A **Deployment** is a Kubernetes resource that manages a set of identical Pods. It ensures the desired number of replicas are running and handles rolling updates and rollbacks.

**Key Features:**
- **Replicas**: Number of identical pods to run
- **Self-healing**: Automatically replaces failed pods
- **Load balancing**: Traffic distributed across all healthy replicas
- **Zero-downtime updates**: Rolling updates with configurable strategies

**Our Setup:**
- **app1**: 1 replica
- **app2**: 3 replicas (demonstrates high availability)
- **app3**: 1 replica

When a pod in app2 crashes:
1. Service immediately removes it from the endpoint list
2. Traffic redirects to the remaining 2 healthy pods
3. Deployment controller spawns a replacement pod automatically
4. Once healthy, the new pod is added back to the load balancer pool

#### 2. Services
A **Service** is an abstraction that defines a logical set of Pods and a policy to access them. It provides:
- **Stable IP/DNS**: Pods get new IPs when restarted, Services don't
- **Load balancing**: Distributes traffic across all pods matching the selector
- **Service discovery**: Other pods can find services by name

**Service Types:**
- `ClusterIP` (default): Only accessible within the cluster
- `NodePort`: Exposes on each node's IP at a static port
- `LoadBalancer`: Creates an external load balancer (cloud provider)

**Our Setup:**
- All three services use `ClusterIP` type
- Service exposes port 80
- Traffic forwarded to pod port 5678 (hashicorp/http-echo default)

#### 3. Ingress with Traefik
An **Ingress** is a Kubernetes resource that manages external access to services. It provides:
- **HTTP/HTTPS routing**: Route traffic based on host or path
- **SSL/TLS termination**: Handle certificates centrally
- **Name-based virtual hosting**: Multiple domains on one IP

**Traefik** is the default Ingress controller in K3s. It automatically:
- Detects Ingress resources
- Configures routing rules
- Handles load balancing to services

## File Structure

```
p2/
├── Vagrantfile                    # VM configuration
├── confs/
│   ├── app1.yaml                  # Deployment + Service for app1
│   ├── app2.yaml                  # Deployment (3 replicas) + Service for app2
│   ├── app3.yaml                  # Deployment + Service for app3
│   └── ingress.yaml               # Host-based routing configuration
└── scripts/
		└── install-k3s-server.sh      # K3s installation and app deployment
```

## Key Concepts to Understand

### Labels and Selectors
Labels are key-value pairs attached to resources. Selectors are used to filter resources by labels.

```yaml
# Deployment creates pods with this label
template:
	metadata:
		labels:
			app: app2

# Service routes traffic to pods with this label
selector:
	app: app2
```

### Pod Lifecycle
1. **Pending**: Waiting for scheduler
2. **Running**: All containers started
3. **Succeeded/Failed**: Terminated
4. **Unknown**: Communication lost with node

### Service Discovery
Services get DNS names automatically: `<service-name>.<namespace>.svc.cluster.local`
- Example: `app1-service.default.svc.cluster.local`

### Readiness vs Liveness Probes
- **Liveness**: Restart container if unhealthy
- **Readiness**: Remove from service endpoints if not ready

## Configuration Details

### Deployment Configuration (app2.yaml example)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
	name: app2
spec:
	replicas: 3                    # Run 3 identical pods
	selector:
		matchLabels:
			app: app2                  # Manage pods with this label
	template:                      # Pod template
		metadata:
			labels:
				app: app2                # Label applied to each pod
		spec:
			containers:
			- name: app2
				image: hashicorp/http-echo:latest
				args:
					- "-text=Hello from App2"
				ports:
				- containerPort: 5678    # Container listens on 5678
---
apiVersion: v1
kind: Service
metadata:
	name: app2-service
spec:
	selector:
		app: app2                    # Route to pods with this label
	ports:
	- port: 80                     # Service exposed on port 80
		targetPort: 5678             # Forward to container port 5678
```

### Ingress Configuration
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
	name: apps-ingress
spec:
	rules:
	- host: app1.com               # Match requests with Host: app1.com
		http:
			paths:
			- path: /
				pathType: Prefix
				backend:
					service:
						name: app1-service   # Route to this service
						port:
							number: 80
```

## Setup and Testing

### 1. Deploy the Infrastructure
```bash
cd p2
vagrant up
```

### 2. Access from Host Machine
Add to `/etc/hosts`:
```
192.168.56.110 app1.com
192.168.56.110 app2.com
192.168.56.110 app3.com
```

### 3. Test the Applications
**Using Browser:**
- http://app1.com
- http://app2.com
- http://app3.com

**Using curl:**
```bash
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl -H "Host: app3.com" http://192.168.56.110
```

### 4. Verify Deployment
SSH into the VM and check resources:
```bash
vagrant ssh

# Check all pods
kubectl get pods -A

# Check deployments
kubectl get deployments

# Check services
kubectl get services

# Check ingress
kubectl get ingress

# Detailed pod info
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Test service endpoints
kubectl get endpoints
```

## Common Issues and Troubleshooting

### Issue: "Bad Gateway" Error
**Cause:** Service targetPort doesn't match container port

**Solution:** Ensure `hashicorp/http-echo` uses port 5678:
```yaml
ports:
- containerPort: 5678
---
ports:
- port: 80
	targetPort: 5678  # Must match containerPort
```

### Issue: "serviceaccount 'default' not found"
**Cause:** K3s API server not ready when applying manifests

**Solution:** Wait for API readiness in install script:
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
until kubectl get sa default -n default >/dev/null 2>&1; do
	sleep 2
done
```

### Issue: "unknown field 'containers'"
**Cause:** YAML structure error - `containers` must be under `spec`

**Solution:**
```yaml
# Wrong
metadata:
	name: hello-world
containers:  # ❌ Wrong level

# Correct
metadata:
	name: hello-world
spec:
	containers:  # ✅ Under spec
```

### Issue: Pods Not Showing
**Debug steps:**
```bash
# Check all namespaces
kubectl get pods -A

# Check deployment status
kubectl get deployments
kubectl describe deployment app2

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check service endpoints (should list pod IPs)
kubectl get endpoints app2-service
```

## Key Takeaways

1. **Deployments** manage pods and ensure desired state (replicas, health)
2. **Services** provide stable networking and load balancing
3. **Ingress** handles external routing based on host/path rules
4. **Labels and Selectors** connect deployments, services, and pods
5. **K3s** includes Traefik by default - no separate ingress controller needed
6. **Port mapping**: External (80) → Service (80) → Target (5678) → Container (5678)
7. **High availability**: Multiple replicas automatically load-balanced with failover
