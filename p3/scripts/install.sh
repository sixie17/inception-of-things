#!/bin/bash
# check docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker is not installed.installing docker..."
    echo "removing conflicting packages..."
    sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)
    echo "installing docker..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
fi
# check kubectl is installed
if ! command -v kubectl &> /dev/null
then
    echo "kubectl is not installed.installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi
# Check if k3d is installed
if ! command -v k3d &> /dev/null
then
    wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi
