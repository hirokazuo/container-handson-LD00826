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



### aiueo

* 12345
* 
|テスト。|
|:-|

|テスト。|
|:-|
