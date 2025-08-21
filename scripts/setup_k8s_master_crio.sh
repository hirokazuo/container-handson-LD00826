#!/bin/bash

####################################################################################
# Update: 2025-08-13
# NetApp LOD: LD00826
# Setup k8s master node on mgmt01
# Host OS: Ubuntu 20.04.4 LTS
# CRI: CRI-O v1.33
# Kubernetes version: v1.33
# Pod network: Calico
# Load Blancer: MetalLB (IP Address Pool :192.168.0.201-240)
# note: 
####################################################################################

KUBERNETES_VERSION=v1.33
CRIO_VERSION=v1.33

# --------------------------------------------------------------------------------
# /root/.docker/config.jsonの更新
# 自分のクレデンシャル情報で作成したconfig.jsonに置き換わっていることを確認してください
# --------------------------------------------------------------------------------

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
# kubernetes マスターノードセットアップ
# --------------------------------------------------------------------------------

# Bootstrap a cluster
swapoff -a
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1
sysctl -w fs.inotify.max_user_instances=2280
sysctl -w fs.inotify.max_user_watches=1255360

# Pod networkのCIDRを設定して初期化
# (LODの環境が192.168.0.0/24を使っているため10.244.0.0/16を指定)
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 > kubeadminit.log
sleep 30

#kubeconfig ファイルを作成して kubectl をクラスターに接続
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Podをコントロールプレーンノードにスケジューリング(1ノードクラスタ時に必要)
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-

# Docker Login用認証情報を設定
kubectl create secret generic regcred --from-file=.dockerconfigjson=/root/.docker/config.json --type=kubernetes.io/dockerconfigjson

# Pod network: Calico設定
curl -O -L  https://docs.projectcalico.org/manifests/calico.yaml
kubectl apply -f calico.yaml

sleep 60

# Load balancer:  MetalLB設定 最新版は https://metallb.io/installation/ にて確認
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

sleep 80

# Load balancer:  IP Addressプール設定
cat <<EOF | sudo tee $HOME/ipaddresspool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 192.168.0.221-192.168.0.240
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default

EOF

kubectl apply -f $HOME/ipaddresspool.yaml

sleep 20

# テスト用Pod作成 nginx
cat <<EOF | sudo tee $HOME/nginx-test.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-test
  labels:
    run: nginx
spec:
  type: LoadBalancer
  ports:
  - port: 80
    protocol: TCP
  selector:
    run: nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      run: nginx
  replicas: 2
  template:
    metadata:
      labels:
        run: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80

EOF

kubectl apply -f nginx-test.yaml


#######################################################
# Trident インストール
#######################################################
# trident用のnamespaceを作成
kubectl create namespace trident

wget https://github.com/NetApp/trident/releases/download/v25.06.0/trident-installer-25.06.0.tar.gz
tar -xf trident-installer-25.06.0.tar.gz
$HOME/trident-installer/tridentctl install -n trident

sleep 100


# Tridentにバックエンド登録
# 本来はcp sample-input/<backend template>.json backend.json　して編集
# 本スクリプトでは backend.json を直接作成
cat <<EOF | sudo tee $HOME/trident-installer/backend.json
{
    "version": 1,
    "storageDriverName": "ontap-nas",
    "backendName": "NFS_ONTAP_Backend",
    "managementLIF": "192.168.0.101",
    "dataLIF": "192.168.0.121",
    "svm": "svm1",
    "username": "admin",
    "password": "Netapp1!"
}
EOF

$HOME/trident-installer/tridentctl -n trident create backend -f $HOME/trident-installer/backend.json


# StorageClassの定義
# NFSバックエンドのONTAPでのStorageClass

cat <<EOF | sudo tee $HOME/trident-installer/StorageClassFastest.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  name: ontap-gold
provisioner: csi.trident.netapp.io
parameters:
  backendType: "ontap-nas"
  media: "ssd"
  provisioningType: "thin"
  snapshots: "true"
EOF

kubectl apply -f $HOME/trident-installer/StorageClassFastest.yaml

# Create volume snapshot CRDs.
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.1/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.1/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.1/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

# Create the snapshot controller.
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.1/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.1/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml

# Create Volume Snapshot Class
cat <<EOF | sudo tee $HOME/trident-installer/VolumeSnapshotClass.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
driver: csi.trident.netapp.io
deletionPolicy: Delete
EOF

kubectl apply -f $HOME/trident-installer/VolumeSnapshotClass.yaml

# 動作確認用PVCの作成
cat <<EOF | sudo tee $HOME/pvctest.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvctest
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ontap-gold
EOF

kubectl apply -f $HOME/pvctest.yaml

sleep 20

# 動作確認用のSnapshotの作成
cat <<EOF | sudo tee $HOME/snapshot-test.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: pvctest-snap
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: pvctest
EOF

kubectl apply -f $HOME/snapshot-test.yaml

sleep 20

# Tridentがインストールされたことを確認(tridentctlは以下のパスに存在)
echo -e "\n\n\nインストールされたTridentのバージョンはこちらになります\n"
$HOME/trident-installer/tridentctl -n trident version

# PVCとSnapshotが作成されていることを確認
echo -e "\nPVCとSnapshotが作成されていることを確認します\n"
kubectl get pvc
kubectl get volumesnapshots

# テスト用nginx podのexternal IPを確認
echo -e "\n\n\nEXTERNAL-IPをつかってテスト用nginxにブラウザからアクセスします\n"
kubectl get svc nginx-test


# worker nodeセットアップ用コマンドを確認 
echo -e "\n\n\n以下のコマンドを使ってkubernates workerノードをセットアップします\n"
kubeadm token create --print-join-command


