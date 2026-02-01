#!/bin/bash
set -euo pipefail

apt-get update -y

curl -sfL https://get.k3s.io | sh -s - server \
    --write-kubeconfig-mode=0644

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
until kubectl get sa default -n default >/dev/null 2>&1; do
  sleep 2
done

kubectl apply -f /vagrant/confs/app1.yaml
kubectl apply -f /vagrant/confs/app2.yaml
kubectl apply -f /vagrant/confs/app3.yaml
kubectl apply -f /vagrant/confs/ingress.yaml