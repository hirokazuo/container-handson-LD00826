# Lab0: Kubernetesクラスターのセットアップ
Kubernetesの公式ドキュメントは以下となります。
* https://kubernetes.io/ja/docs/home/

K8sクラスターを構築する手順は以下「kubeadmセットアップツールのインストール」から確認できます。
* https://kubernetes.io/ja/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

## kubernetesマスターノードのセットアップ
* ホスト **mgmt01** をマスターノードしてセットアップします。
* JumphostからSSHを使ってログインします。



### マスターノードKubernetesクラスタ構築準備手順例 (mgmt01上で実行)

```
# Kubernetes、CRI-Oバージョンの変数を設定
KUBERNETES_VERSION=v1.33
CRIO_VERSION=v1.33

# リポジトリを追加するための依存関係を設定
apt-get update
apt-get install -y software-properties-common curl

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

# Bootstrap a cluster
swapoff -a
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1

# Pod networkのCIDRを設定して初期化
# (LODの環境が192.168.0.0/24を使っているため10.244.0.0/16を指定)
kubeadm init --pod-network-cidr=10.244.0.0/16

#kubeconfig ファイルを作成して kubectl をクラスターに接続
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Podをコントロールプレーンノードにスケジューリング(1ノードクラスタ時に必要)
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-

# Docker Login用認証情報を設定
kubectl create secret generic regcred --from-file=.dockerconfigjson=/root/.docker/config.json --type=kubernetes.io/dockerconfigjson

# Pod network: Calico設定
curl -O -L https://docs.projectcalico.org/manifests/calico.yaml
kubectl apply -f calico.yaml

```

#### `kubeadm init`コマンド実行結果の確認
`Your Kubernetes control-plane has initialized successfully!`のメッセージが出力されていることを確認します。
またメッセージの末尾にワーカーノード用の`kubeadm join`コマンドが出力されていますので、自身の端末に文字列をコピーしてください。


以下は出力サンプルです。
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.0.203:6443 --token 6zekdp.18g39vcoxg7sjvm9 \
	--discovery-token-ca-cert-hash sha256:0b834c42c8d3a484c27df33de06adc66fb49e98f41c130f17dd3fbc8a91d4378 
```


## kubernetesワーカーノードのセットアップ
**gpu01** をワーカーノードとしてセットアップします。<br>
Jumphostから別のコンソールを立ち上げてSSHを使って**gpu01**にログインします。


### ワーカーノードKubernetesクラスタ構築準備手順例 (gpu01上で実行)
```
# Kubernetes、CRI-Oバージョンの変数を設定
KUBERNETES_VERSION=v1.33
CRIO_VERSION=v1.33

# リポジトリを追加するための依存関係を設定
apt-get update
apt-get install -y software-properties-common curl

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

# Bootstrap a cluster
swapoff -a
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1

# 新たなワーカーノードとしてクラスタに追加（token含むコマンド情報は自分自身の環境で出力された文字列を利用）
kubeadm join 192.168.0.203:6443 --token 6zekdp.18g39vcoxg7sjvm9 \
	--discovery-token-ca-cert-hash sha256:0b834c42c8d3a484c27df33de06adc66fb49e98f41c130f17dd3fbc8a91d4378 
```
