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
