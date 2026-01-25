#!/bin/bash
set -euo pipefail

apt-get update -y

echo "Waiting for token file..."
while [ ! -f /vagrant/confs/k3s-token.txt ]; do sleep 2; done
TOKEN=$(cat /vagrant/confs/k3s-token.txt)
echo "Token found."

# Detect worker iface/IP
IFACE=$(ip -o -4 addr show | awk '$4 ~ /^192\.168\.56\./ {print $2; exit}')
NODE_IP=$(ip -o -4 addr show | awk '$4 ~ /^192\.168\.56\./ {print $4}' | cut -d/ -f1 | head -1)

if [ -z "${IFACE:-}" ] || [ -z "${NODE_IP:-}" ]; then
  echo "ERROR: Could not detect iface/IP on 192.168.56.x"
  ip -o -4 addr show
  exit 1
fi

echo "Waiting for server API..."
until curl -k --http1.1 -sS -o /dev/null https://192.168.56.110:6443 || nc -z 192.168.56.110 6443; do
  echo "Server API not reachable, waiting..."
  sleep 2
done

# Install agent
curl -sfL https://get.k3s.io | K3S_URL="https://192.168.56.110:6443" K3S_TOKEN="$TOKEN" sh -s - agent \
  --node-ip="$NODE_IP" \
  --node-external-ip="$NODE_IP" \
  --flannel-iface="$IFACE"

# Optional: kubeconfig on worker
mkdir -p /home/vagrant/.kube
cp /vagrant/confs/k3s.yaml /home/vagrant/.kube/config 2>/dev/null || true
chown -R vagrant:vagrant /home/vagrant/.kube 2>/dev/null || true

echo "K3s agent installed and joined cluster"