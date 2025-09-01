# Web UI (Dashboard)の設定
ダッシュボードUIを作成したKubernetesクラスタ上に構築します。
以下、日本語のドキュメントがありますが、インストール手順が古いため、英語版を参考にします。
* https://kubernetes.io/ja/docs/tasks/access-application-cluster/web-ui-dashboard/

Deploy and Access the Kubernetes Dashboard
* https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/

## Helmのインストール
ここで紹介されているインストール手順は**Helm**を使った手順となるため、まずはKubernetes用パッケージマネージャーの Helm をインストールします

インストール用のスクリプトをダウンロードします。
```
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
```

スクリプトに実行権限を付与します。
```
$ chmod +x get_helm.sh
```

スクリプトを実行します。
```
$ ./get_helm.sh

Downloading https://get.helm.sh/helm-v3.18.6-linux-amd64.tar.gz
Verifying checksum... Done.
Preparing to install helm into /usr/local/bin
helm installed into /usr/local/bin/helm
```

## kubernetes-dashboard のインストール
kubernetes-dashboard レポジトリを追加
```
$ helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

"kubernetes-dashboard" has been added to your repositories
```

kubernetes-dashboard チャートを使って`kubernetes-dashboard`という名前のHelmリリースをデプロイ
```
$ helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard

Release "kubernetes-dashboard" does not exist. Installing it now.
NAME: kubernetes-dashboard
LAST DEPLOYED: Mon Sep  1 14:18:55 2025
NAMESPACE: kubernetes-dashboard
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
*************************************************************************************************
*** PLEASE BE PATIENT: Kubernetes Dashboard may need a few minutes to get up and become ready ***
*************************************************************************************************

Congratulations! You have just installed Kubernetes Dashboard in your cluster.

To access Dashboard run:
  kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443

NOTE: In case port-forward command does not work, make sure that kong service name is correct.
      Check the services in Kubernetes Dashboard namespace using:
        kubectl -n kubernetes-dashboard get svc

Dashboard will be available at:
  https://localhost:8443
```










