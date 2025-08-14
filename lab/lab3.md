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
$ kubectl create secret generic mysql-pass --from-literal=password=YOUR_PASSWORD
```

作成後は以下のコマンドで結果を確認します。
```
$ kubectl get secrets

     NAME                  TYPE                    DATA      AGE
      mysql-pass            Opaque                  1         42s
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
apiVersion: apps/v1 # for versions before 1.9.0 use apps/v1beta2
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
kubectl create -f mysql-deployment.yaml
```

少々時間がかかるのでどのように状態が移って行くか確認し、「Status」が「Running」になることを確認してください。

```
$ kubectl get pods

NAME                               READY     STATUS    RESTARTS   AGE
wordpress-mysql-1894417608-x5dzt   1/1       Running   0          40s
```


WordPressのデプロイ







## 
