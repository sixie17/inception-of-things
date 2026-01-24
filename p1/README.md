# Part 1 (P1) - Kubernetes Multi-Node Cluster Setup

## Overview
Part 1 sets up a multi-node Kubernetes cluster using K3s running on Ubuntu VMs managed by Vagrant. The goal is to create a k3s server (control plane) and a k3s agent (worker node) to demonstrate a working Kubernetes cluster architecture.

## K3s Architecture

![K3s Architecture](../Learning_Marerail/k3s_architecture.jpg)

### Server vs Agent

**K3s Server (Control Plane)**
- Runs the full Kubernetes control plane components:
  - **API Server**: Entry point for all Kubernetes API requests
  - **Controller Manager**: Manages cluster state and reconciliation loops
  - **Scheduler**: Assigns pods to nodes based on resource availability
  - **Supervisor**: Manages and monitors all k3s processes
- Stores cluster state in an embedded database (SQLite by default)
- Exposes the Kubernetes API on port 6443
- Can optionally run workloads (pods) when configured with `--disable-agent=false`

**K3s Agent (Worker Node)**
- Runs only the worker components:
  - **Kubelet**: Manages containers and pods on the node
  - **Kube Proxy**: Handles network routing for services
  - **Tunnel Proxy**: Establishes secure tunnel to the server
  - **Flannel**: Provides pod-to-pod networking via VXLAN overlay
- Connects to the server using the API server URL (`https://server:6443`)
- Requires a join token from the server for authentication
- Reports node status and receives workload assignments from the scheduler

### What We're Building
1. **`ysakineS`** - K3s Server node (control plane + worker)
2. **`ysakineSW`** - K3s Agent node (worker only, joins the server)

This creates a 2-node cluster where the server manages the cluster and both nodes can run application workloads.

## Current Setup

### Virtual Machine Configuration
- **Name**: `ysakineS`
- **Base Image**: `ubuntu/bionic64` (Ubuntu 18.04)
- **Provider**: VirtualBox
- **Resources**:
  - Memory: 1024 MB
  - CPUs: 1

### Networking
- **NAT Adapter** (enp0s3): `10.0.2.15` (default, for internet access)
- **Host-Only Adapter** (enp0s8): `192.168.56.110` (for host-to-VM communication)
- **SSH Forwarded Port**: Guest port 22 → Host port 1337

### Provisioning (Current)
The VM is provisioned with:
1. **Static IP Configuration**: Sets up udev rules to ensure eth1 interface gets the static IP `192.168.56.110`
2. **K3s Installation**: Installs Kubernetes via K3s using the official installer script
3. **Firewall Rules**: Enables UFW firewall with necessary ports:
   - `6443/tcp` - Kubernetes API server
   - `8472/udp` - Flannel VXLAN
   - `10250/tcp` - Kubelet API

## How to Use

### Start the VM
```bash
# the flag forces the provisionning script
vagrant up --provision 
```

### SSH into the VM
```bash
# Using Vagrant
vagrant ssh ysakineS

# Or using SSH directly on host port 1337
ssh -i .vagrant/machines/ysakineS/virtualbox/private_key vagrant@127.0.0.1 -p 1337
```

### Access Kubernetes
Once provisioned, K3s is running inside the VM:
```bash
vagrant ssh ysakineS
sudo kubectl get nodes
sudo kubectl get pods --all-namespaces
```

### Stop/Destroy the VM
```bash
vagrant halt        # Stop the VM
vagrant destroy     # Delete the VM entirely
```

## Future Plans

### Refactor Provisioning to External Scripts
The current inline provisioning script will be moved to the `scripts/` directory for better maintainability:

- **scripts/setup-network.sh** - Handle network configuration and static IP setup
- **scripts/install-k3s.sh** - K3s installation and configuration
- **scripts/setup-firewall.sh** - UFW firewall rules

The Vagrantfile will be updated to call these scripts:
```ruby
config.vm.provision "shell", path: "scripts/setup-network.sh"
config.vm.provision "shell", path: "scripts/install-k3s.sh"
config.vm.provision "shell", path: "scripts/setup-firewall.sh"
```

This will allow for:
- Better code organization and reusability
- Easier debugging and testing of individual components
- Potential sharing of scripts with other VMs (e.g., `ysakineSW` worker node)

## Project Structure
```
p1/
├── Vagrantfile              # Vagrant configuration
├── README.md                # This file
├── confs/                   # Configuration files (for future use)
└── scripts/                 # Provisioning scripts (to be populated)
    ├── setup-network.sh     # (Planned)
    ├── install-k3s.sh       # (Planned)
    └── setup-firewall.sh    # (Planned)
```

## Notes
- **Current Status**: Server node (`ysakineS`) is configured and running k3s server
- **Next Step**: Add the worker node (`ysakineSW`) to create a full 2-node cluster
- K3s automatically starts on boot, making the cluster immediately available after VM startup
- Both VMs are resource-constrained (1 CPU, 1GB RAM each) suitable for development/testing; adjust in Vagrantfile for production
- Network interfaces in the guest OS use predictable naming (`enp0s3`, `enp0s8`) instead of `eth0`/`eth1`
