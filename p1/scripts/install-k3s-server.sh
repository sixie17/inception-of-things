#!/bin/bash
set -euo pipefail

apt-get update -y

# Detect the 192.168.56.x interface
IFACE=$(ip -o -4 addr show | awk '$4 ~ /^192\.168\.56\./ {print $2; exit}')
NODE_IP=$(ip -o -4 addr show | awk '$4 ~ /^192\.168\.56\./ {print $4}' | cut -d/ -f1 | head -1)

if [ -z "${IFACE:-}" ] || [ -z "${NODE_IP:-}" ]; then
  echo "ERROR: Could not detect iface/IP on 192.168.56.x"
  ip -o -4 addr show
  exit 1
fi

TOKEN=$(openssl rand -base64 32)
mkdir -p /vagrant/confs
echo "$TOKEN" > /vagrant/confs/k3s-token.txt

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.28.15+k3s1" sh -s - server \
  --bind-address=0.0.0.0 \
  --advertise-address="$NODE_IP" \
  --node-ip="$NODE_IP" \
  --flannel-iface="$IFACE" \
  --tls-san="$NODE_IP" \
  --write-kubeconfig-mode=0644 \
  --token="$TOKEN"

ufw disable || true

mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sed -i "s/127.0.0.1/$NODE_IP/g" /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# Share kubeconfig with the worker
cp /home/vagrant/.kube/config /vagrant/confs/k3s.yaml

echo "K3s server ready on $NODE_IP ($IFACE)"