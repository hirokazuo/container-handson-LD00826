# Lab0: Kubernetesクラスターのセットアップ
Kubernetesの公式ドキュメントは以下となります。
* https://kubernetes.io/ja/docs/home/

K8sクラスターを構築する手順は以下「kubeadmセットアップツールのインストール」から確認できます。
* https://kubernetes.io/ja/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
** ああ 


## コンテナランタイムおよび kubeadm、kubelet、kubectlのインストール
今回のハンズオンではコンテナランタイム 「CRI-O」を使用して Kubernetes環境を構築します。
Kubernetes公式サイトにある「CRI-Oのインストール手順」リンク先の以下ドキュメントに CRI-O および kubeadm、kubelet、kubectlのインストール手順が掲載されています。
こちらの手順に従ってCRI-Oバージョン1.33、Kubernetesバージョン1.33用のkubeadm、kubelet、kubectlをインストールしてください。
「Bootstrap a cluster」設定は次のステップで実施しますので`kubeadm init` はここでは実施しないでください。
### CRI-O Packaging
* https://github.com/cri-o/packaging/blob/main/README.md#distributions-using-deb-packages
* `kubeadm init` は実施しない


### （補足）インストール手順解説
公式サイトから確認できた手順と見比べてみてください。
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
```

## kubeadmを使用したクラスターの作成
以下のドキュメントに従ってKubernetesクラスターをインストールします。
* https://kubernetes.io/ja/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

作業内容以下となります。
1. シングルコントロールプレーンのKubernetesクラスターをインストールします
2. クラスター上にPodネットワークをインストールして、Podがお互いに通信できるようにします
    1. Podネットワークがホストネットワークと重ならないようにする(LODの環境が192.168.0.0/24を使っているため`kubeadm init`のオプションは`--pod-network-cidr=10.244.0.0/16`を指定)
    2. PodネットワークアドオンはCalicoを利用
       * https://docs.tigera.io/calico/latest/about/


### （補足）インストール手順解説
公式サイトから確認できた手順と見比べてみてください。
```
# Bootstrap a cluster
swapoff -a
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1

# Pod networkのCIDRを設定して初期化
# (LODの環境が192.168.0.0/24を使っているため10.244.0.0/16を指定)
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

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
```






インストール
