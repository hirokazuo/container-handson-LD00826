#!/bin/bash

####################################################################################
# NetApp LOD: 
# Setup k8s worker node on gpu01
# Host OS: Ubuntu 20.04.4 LTS
# CRI: CRI-O
# Kubernetes version: v1.30
# note: 
####################################################################################

KUBERNETES_VERSION=v1.33
CRIO_VERSION=v1.33

####################################################################################
# Container runtimes: install CRI-O, kubelet, kubeadm and kubectl
# https://github.com/cri-o/packaging/blob/main/README.md#distributions-using-deb-packages
####################################################################################

# Install the dependencies for adding repositories
apt-get update
apt-get install -y software-properties-common curl

# Add the Kubernetes repository
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/kubernetes.list

# Add the CRI-O repository
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/cri-o.list


# Install the packages
apt-get update
apt-get install -y cri-o kubelet kubeadm kubectl

# Start CRI-O
systemctl start crio.service

#######################################################
# Setup kubernetes worker node
#######################################################

# Bootstrap a cluster
swapoff -a
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1
sysctl -w fs.inotify.max_user_instances=2280
sysctl -w fs.inotify.max_user_watches=1255360




echo -e "\n\n\n続いて、kubernates masterノードをセットアップ時に確認したkubeadm joinコマンドを使ってこのホストをkubernatesクラスタに参加させます\n"
