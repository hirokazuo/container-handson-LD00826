# Lab1: kubernetes基本操作

## デプロイメント
kubernetesクラスタに作成したコンテナアプリケーションをデプロイするためには 「Deployment」を作成します。 kubectlを使用して、アプリケーションをデプロイします。<br>
今回はnginxのWebサーバーを作成します<br>
以下では `kubectl create deployment` を実行すると「Deployment」が作成されます。

以下の例では `my-nginx` がデプロイメント名
```
root@mgmt01:~# kubectl create deployment 任意のデプロイメント名 --image=nginx --port=80

deployment.apps/my-nginx created
```

<br><br>
デプロイが完了したら以下のコマンドで状況を確認します。

```
root@mgmt01:~# kubectl get deployments

NAME       READY   UP-TO-DATE   AVAILABLE   AGE
my-nginx   1/1     1            1           78s
```

<br><br>
Podの状態を以下のコマンドで状況を確認します。

```
root@mgmt01:~# kubectl get pod

NAME                        READY   STATUS    RESTARTS   AGE
my-nginx-86b474f5bb-qlgzf   1/1     Running   0          16m
```
Pod名とデプロイメント名が異なることを確認してください。

<br><br>
デプロイしたアプリケーションのサービスを確認します。 まだこの状態ではデプロイしたアプリケーションのサービスは存在しない状況です。

```
root@mgmt01:~# kubectl get services

kubectl get services
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   95m
```

<br>

## 外部向けに公開
外部向けにサービスを公開します。 公開後、再度サービスを確認します。

```
root@mgmt01:~# kubectl expose deployment/上記のデプロイメント名 --type="NodePort" --port 80

service "my-nginx" exposed
```

`kubectl expose` コマンドで外部へ公開しました。


<br><br>
サービス一覧から公開されたポートを確認します。

```
root@mgmt01:~# kubectl get services

NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP        99m
my-nginx     NodePort    10.101.151.52   <none>        80:31600/TCP   53s

```

<br><br>
PORT 列を確認します。上の実行例でいうと「31600」ポートの部分を確認します。

`--type="NodePort"` を指定すると各ノード上にアプリケーションにアクセスするポート（標準で30000–32767）を作成します。 ノードにアクセスしポッドが動いていれば、そのままアクセスします。 ノードにポッドがなければ適切なノード転送される仕組みを持っています。 そのためマスターノードにアクセスすればk8sが適切に転送するという動作をします。

<br><br>
ホストのIPを確認します。`ifconfig`コマンドが使えない場合には`net-tools`をインストールします。
```
root@mgmt01:~# sudo apt install net-tools

root@mgmt01:~# ifconfig -a | grep 192.168.*

  inet 192.168.0.203  netmask 255.255.255.0  broadcast 192.168.0.255
```

上記の情報を元にIPを生成してアクセスします。<br>
Jumphost上のChromeプラウザを起動して以下のURLでアクセスします。

* http://確認したIP:確認したポート番号/

アクセス時に「**Welcome to nginx!**」のメッセージが表示されれば稼働確認完了です。


<br><br>
nginex Webサーバの状態を確認します。

```
root@mgmt01:~# kubectl describe deployment my-nginx
Name:                   my-nginx
Namespace:              default
CreationTimestamp:      Fri, 15 Aug 2025 06:39:04 +0000
Labels:                 app=my-nginx
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=my-nginx
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=my-nginx
  Containers:
   nginx:
    Image:         nginx
    Port:          80/TCP
    Host Port:     0/TCP
    Environment:   <none>
    Mounts:        <none>
  Volumes:         <none>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   my-nginx-86b474f5bb (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  12m   deployment-controller  Scaled up replica set my-nginx-86b474f5bb from 0 to 1

```

Replicas の項目で `1 available` となっていればデプロイメント成功です。

<br>

## 問題発生時のログの確認方法

デプロイに失敗するようであれば以下のコマンドで状態を確認します。

ポッドの状態を確認するコマンド
```
root@mgmt01:~# kubectl logs ポッド名
```

<br><br>
デプロイメントの状態を確認するコマンド
```
root@mgmt01:~# kubectl describe deployments デプロイメント名
```

<br><br>
他にも以下のようなコマンドで状態を確認することができます。 デプロイ時のYAMLファイル単位や、定義しているラベル単位でも情報を確認できます。
```
root@mgmt01:~# kubectl describe -f YAML定義ファイル
root@mgmt01:~# kubectl describe -l ラベル名
```

<br>

## クリーンアップ
Pod名を確認してmy-nginxのポッドを削除します。

```
root@mgmt01:~# kubectl get pod

NAME                        READY   STATUS    RESTARTS   AGE
my-nginx-86b474f5bb-qlgzf   1/1     Running   0          20m

root@mgmt01:~# kubectl delete pod my-nginx-86b474f5bb-qlgzf

pod "my-nginx-86b474f5bb-qlgzf" deleted
```

Podの状態を再度確認します。

```
root@mgmt01:~# kubectl get pod

NAME                        READY   STATUS    RESTARTS   AGE
my-nginx-86b474f5bb-cz4fb   1/1     Running   0          2m
```
Pod名が`my-nginx-86b474f5bb-qlgzf`から`my-nginx-86b474f5bb-cz4fb`変わって再作成されていることが確認できます。


 Podを削除するにはデプロイメントを削除します。
* root@mgmt01:~# kubectl delete deployments デプロイメント名
* root@mgmt01:~# kubectl delete services サービス名
 
```
root@mgmt01:~# kubectl get deployment

NAME       READY   UP-TO-DATE   AVAILABLE   AGE
my-nginx   1/1     1            1           26m

root@mgmt01:~# kubectl delete deployment my-nginx

deployment.apps "my-nginx" deleted

root@mgmt01:~# kubectl get services
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP        122m
my-nginx     NodePort    10.101.151.52   <none>        80:31600/TCP   23m

root@mgmt01:~#  kubectl delete services my-nginx
service "my-nginx" deleted
```

<br>

## まとめ
このラボではこの先のラボを行うための基本となる操作及び環境の確認を実施しました。
よく使うコマンドや問題発生時の確認方法については以下にまとめました。 今後のラボでうまくいかない場合いはぜひ参考にしてください。
<br>

Lab1は以上となります。
[Lab2](https://github.com/hirokazuo/container-handson-LD00826/blob/main/lab/lab2.md)
に進んでください。


<br>

## 補足
### コマンドリファレンス
kubectlの使い方・本家へのリンク
公式ガイドへのリンクです。 詳細や使い方等については以下ページを見ることをおすすめします。 このページではよく使うコマンドについてユースケースでまとめました。

* https://kubernetes.io/docs/reference/kubectl/overview/
* https://kubernetes.io/docs/reference/kubectl/cheatsheet/
* https://kubernetes.io/docs/tasks/debug-application-cluster/debug-application-introspection/
* https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/
* https://kubernetes.io/docs/reference/kubectl/cheatsheet/


<br>

### デプロイメントの実施
`kubectl create/apply/patch/replace`を使用します。
それぞれ便利な点・留意する点があります。

* https://kubernetes.io/docs/concepts/overview/object-management-kubectl/overview/#imperative-object-configuration

<br><br>
kubectl create デプロイメントの基本系、マニフェストファイルを指定してデプロイし、新規に行う場合に使用します。
```
 kubectl create -f deployment.yaml
```

<br><br>
kubectl applyはcreate/replaceを包含できます。差分反映のアルゴリズムを理解して利用しましょう。 applyの動きとしてはすでにデプロイされていれば更新を行い、デプロイされていなければ新規作成の動きをします。
```
 kubectl apply -f deployment.yaml
```

<br><br>
kubectl replace は稼働中のアプリケーションに対して動的に定義を反映する。
```
 kubectl apply -f deployment.yaml
```

<br><br>
kubectl patch は稼働中のアプリケーションに対して、一部のフィールドを書き換える用途に使用。

<br>

### 状況確認
基本形としては `kubectl get オブジェクト名` と `kubectl describe オブジェクト名` になります。 以下は `kubectl get` ですが、`get` を `describe` に変更することで詳細な情報が確認できるようになります。

よく使うものとしては以下の通りです。

```
 kubectl get pod

NAME                               READY     STATUS    RESTARTS   AGE
wordpress-mysql-58cf8dc9f9-t2wnr   1/1       Running   0          2d
 kubectl get svc
```

```
NAME              TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
kubernetes        ClusterIP   10.96.0.1    <none>        443/TCP    10d
wordpress-mysql   ClusterIP   None         <none>        3306/TCP   2d
```

```
 kubectl get deployment

NAME              DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
wordpress-mysql   1         1         1            1           2d
```

<br>

ネームスペースを指定する場合は `-n` オプション、または `--all-namespaces` で全ネームスペースのオブジェクトを確認できます。

```
 kubectl get all -n ネームスペース名
```

<br>

マニフェストファイルを使用している場合は `get` の引数に `-f マニフェストファイル` を指定すると関連するオブジェクトをすべて表示してくれます。
```
 kubectl get -f deployment.yaml
```

<br>

現状のオブジェクトをすべて確認する場合はオブジェクトを指定する箇所に `all` を設定するとすべてのオブジェクトを確認できます。
```
 kubectl get all [-n ネームスペース名]
```

<br>

すべてのネームスペースのすべてのオブジェクトを確認したい場合は以下のとおりです。
```
 kubectl get all --all-namespaces
```

<br>

マニフェストファイルを使用したオブジェクトの確認もできます。
`-f` オプションを使用してデプロイ時に使用したマニフェストファイルを指定すると関連するオブジェクトをすべて表示します。

```
 kubectl get -f wordpress-mysql-deploy.yaml
NAME                  TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
svc/wordpress-mysql   ClusterIP   None         <none>        3306/TCP   2d

NAME                 STATUS    VOLUME                         CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc/mysql-pv-claim   Bound     default-mysql-pv-claim-b5e95   20Gi       RWO            ontap-gold     2d

NAME                     DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/wordpress-mysql   1         1         1            1           2d
```

<br>

### 問題の特定方法について
マニフェストを `kubectl get` と `kubectl describe`, `kubectl logs` を組み合わせて問題箇所を特定していきます。

#### よく使うコマンド
* `kubectl describe オブジェクト名`
* `kubectl describe -f deployment.yaml`

#### トラブルシュートの流れ
1. 問題箇所の特定
    1. `kubectl get -f deployment.yaml` で予期しない動作をしている箇所を発見
    2. `kubectl describe -f deployment.yaml`

2. うまく行っていない箇所が分かれば該当のPodを確認する
    1. `kubectl logs pod ポッド名`
    2. 3rd party製の `stern` というツールもあります。こちらは複数のPodに対して kubectl logs を実行する動きをします。非常に便利なものになります。

3. 取得できた情報を元に対応実施
    1. マニフェストファイルの修正

#### オペレーション簡易化のためデフォルトストレージクラスを設定
サンプルで公開されているマニフェストを試したいときに以下の設定をしておくと簡単に起動できるようになります。

* デフォルトのストレージクラスを設定
```
kubectl patch storageclass [StorageClass名] -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

* external ip が付与できるようにするような仕組みを導入する
  → ラボでLoad Balancerを使った運用を紹介しています。


  



  





  










<br>
<br>
<br>
<br>
<br>
<br>
<br>











