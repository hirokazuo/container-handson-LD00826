# Lab3: アプリケーションをコンテナ化する

## 流れ ※今回は4.5のみを実施します
1. (Optional) Dockerfileを作成する。
2. (Optional) ビルドを行いDockerイメージを作成
3. (Optional) 作成したDockerイメージをイメージレジストリに登録
4. アプリケーションのマニフェストファイルを作成、イメージレジストリに登録したイメージを使用
5. アプリケーションをKubernetes上へデプロイ、稼働確認

## コンテナ化の準備
本ラボでは以下のミドルウェアやスタックを使ったアプリケーションを想定しています。 基本的にはアプリケーションをコンテナ化する際にはDockerHubで作成済みのイメージを使用することで効率よくコンテナ化することができます。

Web/AP レイヤー
* nginx
* apache
* tomcat
  
Databaseレイヤー
* mySQL
* Postgress
* Oracle
* MongoDB

## アプリケーションのマニフェストファイルを作成してデプロイ
Lab1: 基本操作 ではコマンドラインで作成してきましたがYAMLファイルで１サービスをまとめてデプロイ出来るようにします。

ファイルのセクション構成としては以下の通りです。
* Service
* PersistentVolumeClaim
* Deployment

<br>

サンプルファイルを準備しましたのでそれぞれの項目の意味を考え作成してみましょう。<br>
(https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/ を参考としています。）

<br>

ここではサンプルとしてWordPressとMySQLをデプロイします。 MySQLではSecretオブジェクトを使用しパスワードを渡すようになっています。<br>
流れとしては、以下の3つを実施します。<br>
どの部分を実施しているかを把握しながらすすめましょう。
1. MySQL 用のSecretオブジェクトを作成
2. MySQL をデプロイ
3. WordPressをデプロイ


### Secretの作成
ここではKubernetes上でパスワードを受け渡すときなどに使う、Secretを作成します。
Secretの説明はこちらです。

* https://kubernetes.io/docs/concepts/configuration/secret/

```
root@mgmt01:~# kubectl create secret generic mysql-pass --from-literal=password=YOUR_PASSWORD
```

作成後は以下のコマンドで結果を確認します。
```
root@mgmt01:~# kubectl get secrets

NAME         TYPE                             DATA   AGE
mysql-pass   Opaque                           1      12s
regcred      kubernetes.io/dockerconfigjson   1      137m
```

<br>


### MySQLのデプロイ
`mysql-pass` という名前でSecretができたのでそのSecretを使ってMySQLを起動します。

アプリケーションをデプロイするマニフェストファイルの例 mysql-deployment.yaml
```
apiVersion: v1
kind: Service
metadata:
  name: wordpress-mysql
  labels:
    app: wordpress
spec:
  ports:
    - port: 3306
  selector:
    app: wordpress
    tier: mysql
  clusterIP: None
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress-mysql
  labels:
    app: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress
        tier: mysql
    spec:
      containers:
        - image: mysql:5.6
          name: mysql
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-pass
                  key: password
          ports:
            - containerPort: 3306
              name: mysql
```


上記のマニフェストをもとにDeploymentを作成します。

```
root@mgmt01:~# kubectl create -f mysql-deployment.yaml

service/wordpress-mysql created
deployment.apps/wordpress-mysql created
```

少々時間がかかるのでどのように状態が移って行くか確認し、「Status」が「Running」になることを確認してください。

```
root@mgmt01:~# kubectl get pods

NAME                                    READY   STATUS    RESTARTS   AGE
wordpress-mysql-59b85fd8dc-5gdch        1/1     Running   0          2m20s
```


### WordPressのデプロイ
MySQLのコンテナが立ち上がったらそのMySQLに接続するWordPressをデプロイします。


アプリケーションをデプロイするマニフェストファイルの例 wordpress-deployment.yaml
```
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  ports:
    - port: 80
  selector:
    app: wordpress
    tier: frontend
  type: LoadBalancer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: frontend
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress
        tier: frontend
    spec:
      containers:
        - image: wordpress:4.8-apache
          name: wordpress
          env:
            - name: WORDPRESS_DB_HOST
              value: wordpress-mysql
            - name: WORDPRESS_DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-pass
                  key: password
          ports:
            - containerPort: 80
              name: wordpress
```

MySQLと同様にデプロイします。

```
root@mgmt01:~# kubectl create -f wordpress-deployment.yaml
```


### （補足）kubectlの操作を容易にする
上記のマニフェストにも記載がありますが、Labelには複数の使い方があります。 Serviceが接続先を見つけるために使っている例が上記のマニフェストとなります。

* 参考URL: k8s label
kubectlのオペレーションの簡易化のためlabelをつけることをおすすめします。 例えば以下のような使い方があります。

`kubectl get pods -l app=nginx` などのようにlabelがついているPod一覧を取得といったことが簡単にできます。 ほかにも以下の様なことが可能となります。
* `kubectl delete deployment -l app=app_label`
* `kubectl delete service -l app=app_label`
* `kubectl delete pvc -l app=wordpress`


### アプリケーションの稼働確認
デプロイしたアプリケーションにアクセスし正常稼働しているか確認します。
アクセスするIPについてはサービスを取得して確認します。

結果として以下のような出力が得られます。
今回はService.typeをLoadBalancerで指定しているため、EXTERNAL-IP欄に表示されたIPでアクセスしてみましょう。

```
root@mgmt01:~# kubectl get svc

NAME              TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
kubernetes        ClusterIP      10.96.0.1       <none>          443/TCP        179m
wordpress         LoadBalancer   10.102.247.40   192.168.0.222   80:30672/TCP   16s
wordpress-mysql   ClusterIP      None            <none>          3306/TCP  
```

上記のようにTYPE　LoadBalancerでEXTERNAL-IPが設定されていることが確認できます。<br>
ここで確認したIPアドレスをつかってJumphost上のChromeプラウザからアクセスします。
* http://確認したEXTERNAL-IP/ <br>
<br>

アクセス時にWordPressの初期設定画面が表示されれば正常です。<br>
『日本語』を選んで次のセットアップ画面に進んでください。<br>
![WordPress Setup1](https://github.com/hirokazuo/container-handson-LD00826/blob/main/image/lab0301.png)
<br>

『ようこそ』画面に必要な情報を設定してWordPressをインストールします。<br>
![WordPress Setup2](https://github.com/hirokazuo/container-handson-LD00826/blob/main/image/lab0302.png)
<br>
<br>

インストールが成功したら先に設定したユーザでログインします。<br>
![WordPress Setup3](https://github.com/hirokazuo/container-handson-LD00826/blob/main/image/lab0303.png)
<br>
<br>

先に設定したユーザでログインします。<br>
![WordPress Setup4](https://github.com/hirokazuo/container-handson-LD00826/blob/main/image/lab0304.png)
<br>
<br>

『ブログに投稿する』をクリックします。<br>
![WordPress Setup5](https://github.com/hirokazuo/container-handson-LD00826/blob/main/image/lab0305.png)
<br>
<br>

新規投稿を追加します。<br>
タイトルと本文を記入したら『公開』ボタンを押して公開します。<br>
![WordPress Setup6](https://github.com/hirokazuo/container-handson-LD00826/blob/main/image/lab0306.png)
<br>
<br>

投稿が公開されたら『投稿を表示』をクリックして投稿内容を確認します。<br>
![WordPress Setup7](https://github.com/hirokazuo/container-handson-LD00826/blob/main/image/lab0307.png)
<br>
<br>

投稿内容サンプル<br>
![WordPress Setup8](https://github.com/hirokazuo/container-handson-LD00826/blob/main/image/lab0308.png)
<br>
<br>

投稿内容を確認したらkubernetesクラスタ上からmysqlのポッドを削除します。
```
root@mgmt01:~# kubectl get pod

NAME                               READY   STATUS    RESTARTS   AGE
wordpress-6f7cdb5785-lc6t6         1/1     Running   0          5s
wordpress-mysql-59b85fd8dc-wfzmd   1/1     Running   0          2m19s

root@mgmt01:~# kubectl delete pod wordpress-mysql-59b85fd8dc-wfzmd
pod "wordpress-mysql-59b85fd8dc-wfzmd" deleted
```
<br>

ブラウザをリロードして投稿内容が表示されるか確認します。
以下のようにデータベースへの接続エラーが表示されるはずです。
![WordPress Setup9](https://github.com/hirokazuo/container-handson-LD00826/blob/main/image/lab0309.png)


今度はkubernetesクラスタ上からWordPressのポッドを削除します。
```
root@mgmt01:~# kubectl get pod

NAME                               READY   STATUS    RESTARTS   AGE
wordpress-6f7cdb5785-fcdzp         1/1     Running   0          15m
wordpress-mysql-59b85fd8dc-wfzmd   1/1     Running   0          94s


root@mgmt01:~# kubectl delete pod wordpress-6f7cdb5785-fcdzp

pod "wordpress-6f7cdb5785-fcdzp" deleted
```
<br>

再度ブラウザをリロードして投稿内容が表示されるか確認します。<br>
![WordPress Setup10](https://github.com/hirokazuo/container-handson-LD00826/blob/main/image/lab0310.png)

再度、WordPressの初期設定画面が表示されます。<br>
MySQL内のデータが永続されていないのでコンテナが再作成されたときにデータが保持されなかったことが確認できます。
<br>




#### 注釈
kubectl引数の省略系について<br>
今回はServiceの確認をする際に `svc` という省略形でコマンドを実行しました。 他のオブジェクトも同様に省略形があります。コマンド入力を省力化したい場合は省略形も使ってみましょう。
`kubectl --help` や `kubectl XX --help` コマンドで確認できます。

### まとめ
kubectlやYAMLで記載するマニフェストファイルを使ってk8sへのデプロイが体感できたかと思います。 実運用になるとこのYAMLをたくさん書くことは負荷になることもあるかもしれません.
その解決のためにパッケージマネージャーHelm 等を使ってデプロイすることが多いかと思います。 このラボでは仕組みを理解していただき、応用出来ることを目的としています。

<br>
<br>
Lab3は以上となります。Lab4に進んでください。






