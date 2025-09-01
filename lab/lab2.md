# Lab2: LoadBalancerのインストール
Lab1で作成したnginxウェブサーバー手動でExternal-IPを設定しましたが、今回はMetalLBを使ってLoadBalancerでExternal-IPを使用できるようにします。<br>

MetalLBは`Service.type: LoadBalancer`のサービスをを外部に公開するためのツールです。
あらかじめ指定したIPアドレスプールからIPアドレスを割り当て、それを周辺のネットワークに通知することで、外部からのアクセスを可能にします。﻿

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

ロードバランサー用のIPアドレスのプールを設定するためのYAMLファイルを作成します。
* ホームディレクトリに`ipaddresspool.yaml`を作成
* IPアドレスプールは20個（192.168.0.221-192.168.0.240）

以下、ヒアドキュメントでの作成例（viを使った作成でも構いません）
```
$ cat <<EOF | sudo tee $HOME/ipaddresspool.yaml
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

作成したYAMLファイルを使ってロードバランサー用のIPアドレスのプールを設定します。
```
$ kubectl apply -f $HOME/ipaddresspool.yaml

ipaddresspool.metallb.io/default created
l2advertisement.metallb.io/default created
```

再度nginxウェブサーバーのPodを作成します
* 今回はロードバランサーを使ってExternal-IPを設定します。
* Podをデプロイするためののマニフェストをホームディレクトリに作成します。

マニフェスト: nginxweb2.yaml
```
$ cat <<EOF | sudo tee $HOME/nginxweb2.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginxweb2
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
  name: nginxweb2-deployment
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
```

作成したYAMLファイルを使って新しいnginxWebサーバーをデプロイします。
```
$ kubectl apply -f nginxweb2.yaml

service/nginxweb2 created
deployment.apps/nginxweb2-deployment created
```


サービス一覧から公開されたポートを確認します。
```
$ kubectl get services

NAME         TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
kubernetes   ClusterIP      10.96.0.1       <none>          443/TCP        161m
nginxweb2    LoadBalancer   10.108.71.217   192.168.0.221   80:31952/TCP   110s
```
今回はTYPE　LoadBalancerでEXTERNAL-IPが設定されていることが確認できます。


ここで確認したIPアドレスをつかってJumphost上のChromeプラウザからアクセスします。
* http://確認したEXTERNAL-IP/

アクセス時に「**Welcome to nginx!**」のメッセージが表示されれば稼働確認完了です。


Service.Typeについては以下公式ドキュメントに解説があります。
* 参考URL: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types


Lab2は以上です。Lab3に進んでください。
