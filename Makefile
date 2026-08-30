.PHONY: help p1 p1-down p2 p2-down p3 p3-down bonus bonus-down clean

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  p1          bring up p1 (K3s server + agent VMs via Vagrant)"
	@echo "  p1-down     destroy the p1 VMs"
	@echo "  p2          bring up p2 (K3s + 3 apps, 1 VM via Vagrant)"
	@echo "  p2-down     destroy the p2 VM"
	@echo "  p3          install deps, create the p3 k3d cluster, install Argo CD"
	@echo "              (blocks on a port-forward at the end, Ctrl+C to stop forwarding)"
	@echo "  p3-down     delete the p3 k3d cluster"
	@echo "  bonus       deploy GitLab + repoint Argo CD (needs 'make p3' already running)"
	@echo "  bonus-down  remove GitLab and repoint Argo CD back to GitHub"
	@echo "  clean       tear down everything (p1, p2, p3)"
	@echo ""
	@echo "Note: p1 and p2 use the same IP/hostname - don't run both at once."

# --- Part 1: K3s + Vagrant (2 VMs: server + agent) ---
p1:
	cd p1 && vagrant up

p1-down:
	cd p1 && vagrant destroy -f

# --- Part 2: K3s + 3 apps behind Ingress (1 VM) ---
p2:
	cd p2 && vagrant up

p2-down:
	cd p2 && vagrant destroy -f

# --- Part 3: K3d + Argo CD ---
p3:
	cd p3 && bash scripts/install.sh && bash scripts/run-cluster.sh

p3-down:
	k3d cluster delete p3

# --- Bonus: GitLab running inside the p3 cluster ---
bonus:
	cd bonus && bash scripts/run-gitlab.sh

bonus-down:
	kubectl delete namespace gitlab
	kubectl apply -f p3/confs/argocd.yaml

clean: p1-down p2-down p3-down
