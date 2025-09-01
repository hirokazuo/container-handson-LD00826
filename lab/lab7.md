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

kubernetes-dashboardのリソースの確認します。
```
$ kubectl get pod -n kubernetes-dashboard
NAME                                                   READY   STATUS    RESTARTS   AGE
kubernetes-dashboard-api-656d888496-htlnr              1/1     Running   0          3m7s
kubernetes-dashboard-auth-69d9ff4fb6-z9bl9             1/1     Running   0          3m7s
kubernetes-dashboard-kong-648658d45f-g89r2             1/1     Running   0          3m7s
kubernetes-dashboard-metrics-scraper-547874fcf-lw7gx   1/1     Running   0          3m7s
kubernetes-dashboard-web-7796b9fbbb-tb6js              1/1     Running   0          3m7s
```

ブラウザからWeb UIにアクセスするためにサービスの状態を確認します。
```
root@mgmt01:~# kubectl get svc -n kubernetes-dashboard
NAME                                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
kubernetes-dashboard-api               ClusterIP   10.99.6.5        <none>        8000/TCP   4m8s
kubernetes-dashboard-auth              ClusterIP   10.106.138.153   <none>        8000/TCP   4m8s
kubernetes-dashboard-kong-proxy        ClusterIP   10.108.116.248   <none>        443/TCP    4m8s
kubernetes-dashboard-metrics-scraper   ClusterIP   10.106.225.88    <none>        8000/TCP   4m8s
kubernetes-dashboard-web               ClusterIP   10.102.244.190   <none>        8000/TCP   4m8s
```
外部のブラウザからWeb UIにアクセスするには`kubernetes-dashboard-kong-proxy`にアクセスしますが、EXTERNAL-IPが設定されていません。

<br>
ロードバランサーを使って`kubernetes-dashboard-kong-proxy`にEXTERNAL-IPを設定します。

今回は、マニフェストを使わず、`kubectl edit`を使って直接設定を変更します。
```
$ kubectl edit service kubernetes-dashboard-kong-proxy -n kubernetes-dashboard
```


`type: ClusterIP`を `type: LoadBalancer`に書き換えます。
```
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: kubernetes-dashboard
    meta.helm.sh/release-namespace: kubernetes-dashboard
  creationTimestamp: "2025-09-01T14:18:56Z"
  labels:
    app.kubernetes.io/instance: kubernetes-dashboard
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: kong
    app.kubernetes.io/version: "3.8"
    enable-metrics: "true"
    helm.sh/chart: kong-2.46.0
  name: kubernetes-dashboard-kong-proxy
  namespace: kubernetes-dashboard
  resourceVersion: "45712"
  uid: 59f811bf-5e21-4ed8-a34d-bba27df6d488
spec:
  clusterIP: 10.108.116.248
  clusterIPs:
  - 10.108.116.248
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - name: kong-proxy-tls
    port: 443
    protocol: TCP
    targetPort: 8443
  selector:
    app.kubernetes.io/component: app
    app.kubernetes.io/instance: kubernetes-dashboard
    app.kubernetes.io/name: kong
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}
```

編集が終わったらセーブして抜けます。
```
$ kubectl edit service kubernetes-dashboard-kong-proxy -n kubernetes-dashboard
service/kubernetes-dashboard-kong-proxy edited
```

kubernetes-dashboard-kong-proxy のEXTERNAL-IPを確認します。
```
$ kubectl get svc -n kubernetes-dashboard
NAME                                   TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)         AGE
kubernetes-dashboard-api               ClusterIP      10.99.6.5        <none>          8000/TCP        14m
kubernetes-dashboard-auth              ClusterIP      10.106.138.153   <none>          8000/TCP        14m
kubernetes-dashboard-kong-proxy        LoadBalancer   10.108.116.248   192.168.0.223   443:31860/TCP   14m
kubernetes-dashboard-metrics-scraper   ClusterIP      10.106.225.88    <none>          8000/TCP        14m
kubernetes-dashboard-web               ClusterIP      10.102.244.190   <none>          8000/TCP        14m
```


192.168.0.223










