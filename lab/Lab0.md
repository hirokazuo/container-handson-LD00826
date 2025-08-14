# Lab0: Kubernetesクラスターのセットアップ
Kubernetesの公式ドキュメントは以下となります。
* https://kubernetes.io/ja/docs/home/

K8sクラスターを構築する手順は以下「kubeadmセットアップツールのインストール」から確認できます。
* https://kubernetes.io/ja/docs/setup/production-environment/tools/kubeadm/install-kubeadm/


## コンテナランタイムのインストール
今回のハンズオンではコンテナランタイムに 「CRI-O」を使用して Kubernetes環境を構築します。


```
# Kubernetes、CRI-Oバージョンの変数を設定
KUBERNETES_VERSION=v1.33
CRIO_VERSION=v1.33

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
```







インストール
