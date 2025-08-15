#!/bin/bash

####################################################################################
# Update: 2025-08-13
# NetApp LOD: LD00826
# Setup k8s master node on gpu01
# Host OS: Ubuntu 20.04.4 LTS
# CRI: CRI-O v1.33
# Kubernetes version: v1.33
# note: 
####################################################################################

# --------------------------------------------------------------------------------
# /root/.docker/config.jsonの更新
# 自分のクレデンシャル情報で作成したconfig.jsonに置き換わっていることを確認してください
# --------------------------------------------------------------------------------

KUBERNETES_VERSION=v1.33
CRIO_VERSION=v1.33

# --------------------------------------------------------------------------------
# コンテナランタイム CRI-O インストール
# kubelet, kubeadm and kubectl インストール
# https://github.com/cri-o/packaging/blob/main/README.md
# https://cri-o.io/
# distributions-using-deb-packages
# --------------------------------------------------------------------------------

# リポジトリを追加するための依存関係を設定
apt-get update
apt-get install -y software-properties-common curl net-tools

# Ubuntu 22.04より古いリリースでは、/etc/apt/keyringsフォルダーはデフォルトでは存在しないため、curlコマンドの前に作成
mkdir -p -m 755 /etc/apt/keyrings

# Kubernetes リポジトリを追加
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/kubernetes.list

# CRI-O リポジトリを追加
curl -fsSL https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/cri-o.list

# Install the packages
apt-get update
apt-get install -y cri-o kubelet kubeadm kubectl

# Start CRI-O
systemctl start crio.service

# --------------------------------------------------------------------------------
# kubernetes ワーカーノード　セットアップ
# --------------------------------------------------------------------------------

# Bootstrap a cluster
swapoff -a
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1
sysctl -w fs.inotify.max_user_instances=2280
sysctl -w fs.inotify.max_user_watches=1255360


echo -e "\n\n\n続いて、kubernates masterノードをセットアップ時に確認したkubeadm joinコマンドを使ってこのホストをkubernatesクラスタに参加させます\n"
