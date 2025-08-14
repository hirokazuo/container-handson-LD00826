# Lab1

## デプロイメント
kubernetesクラスタに作成したコンテナアプリケーションをデプロイするためには 「Deployment」を作成します。 kubectlを使用して、アプリケーションをデプロイします。

以下では `kubectl run` を実行すると「Deployment」が作成されます。

```
$ kubectl run 任意のデプロイメント名 --image=nginx --port=80

deployment "nginxweb" created
```

デプロイが完了したら以下のコマンドで状況を確認します。

```
$ kubectl get deployments

NAME                                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginxweb                              1         1         1            1           53s
```

デプロイしたアプリケーションのサービスを確認します。 まだこの状態ではデプロイしたアプリケーションのサービスは存在しない状況です。

```
$ kubectl get services

NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   8s
```

## 外部向けに公開
外部向けにサービスを公開します。 公開後、再度サービスを確認します。

```
$ kubectl expose deployment/上記のデプロイメント名 --type="NodePort" --port 80

service "nginxweb" exposed
```

`kubectl expose` コマンドで外部へ公開しました。

サービス一覧から公開されたポートを確認します。

```
$ kubectl get services

NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP        5d
nginxweb     NodePort    10.103.136.206   <none>        80:30606/TCP   1m
```

PORT 列を確認します。上の実行例でいうと「30606」ポートの部分を確認します。

`--type="NodePort"` を指定すると各ノード上にアプリケーションにアクセスするポート（標準で30000–32767）を作成します。 ノードにアクセスしポッドが動いていれば、そのままアクセスします。 ノードにポッドがなければ適切なノード転送される仕組みを持っています。 そのためマスターノードにアクセスすればk8sが適切に転送するという動作をします。

ホストのIPを確認します。













* 12345
* 
|テスト。|
|:-|

|テスト。|
|:-|
