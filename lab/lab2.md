# Lab2: LoadBalancerのインストール
Lab1で作成したnginxウェブサーバー手動でExternal-IPを設定しましたが、今回はMetalLBを使ってLoadBalancerでExternal-IPを使用できるようにします。
MetalLBはService.type: LoadBalancerのサービスをを外部に公開するためのツールです。あらかじめ指定したIPアドレスプールからIPアドレスを割り当て、それを周辺のネットワークに通知することで、外部からのアクセスを可能にします。﻿

## MetalLBのインストール
公式サイトイントールドキュメント
* https://metallb.io/installation/
* 最新バージョンは「Installation by manifest」のコマンドを確認

公式サイトのYAMLファイルを使ってクラスター内にMetalLBのリソースを作成します。
```
$ kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
namespace/metallb-system created
customresourcedefinition.apiextensions.k8s.io/bfdprofiles.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bgpadvertisements.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bgppeers.metallb.io created
customresourcedefinition.apiextensions.k8s.io/communities.metallb.io created
customresourcedefinition.apiextensions.k8s.io/ipaddresspools.metallb.io created
customresourcedefinition.apiextensions.k8s.io/l2advertisements.metallb.io created
customresourcedefinition.apiextensions.k8s.io/servicebgpstatuses.metallb.io created
customresourcedefinition.apiextensions.k8s.io/servicel2statuses.metallb.io created
serviceaccount/controller created
serviceaccount/speaker created
role.rbac.authorization.k8s.io/controller created
role.rbac.authorization.k8s.io/pod-lister created
clusterrole.rbac.authorization.k8s.io/metallb-system:controller created
clusterrole.rbac.authorization.k8s.io/metallb-system:speaker created
rolebinding.rbac.authorization.k8s.io/controller created
rolebinding.rbac.authorization.k8s.io/pod-lister created
clusterrolebinding.rbac.authorization.k8s.io/metallb-system:controller created
clusterrolebinding.rbac.authorization.k8s.io/metallb-system:speaker created
configmap/metallb-excludel2 created
secret/metallb-webhook-cert created
service/metallb-webhook-service created
deployment.apps/controller created
daemonset.apps/speaker created
validatingwebhookconfiguration.admissionregistration.k8s.io/metallb-webhook-configuration created
```

ロードバランサー用のIPアドレスのプールを設定するためのYAMLファイル（ipaddresspool.yaml）をホームディレクトリ作成します。

以下、ヒアドキュメントでの作成例（viを使った作成でも構いません）
```
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
```




