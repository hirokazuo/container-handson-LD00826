# Lab5: アプリケーションのデータ永続化を実現

## 目的・ゴール: アプリケーションのデータ永続化を実現
アプリケーションは永続化領域がないとデータの保存ができません。Lab4ではDynamic provisioningを実現するためDynamic provisionerであるTridentをインストールし動作を確認しましたので、本ラボでは マニフェストファイルを作成しアプリケーションデータの永続化をすることが目標です。

## 流れ
1. Dynamic storage provisioningを実現(Tridentのインストール)
2. StorageClassの作成
3. PVCをkubernetesマニフェストファイルに追加
    1. 作成したStorageClassを使用する
    2. PVCをkubernetesにリクエストした時点で動的にストレージがプロビジョニングされる
4. アプリケーションを稼働させて永続化ができていることを確認

## コンテナでの永続データのカテゴライズ
コンテナ化されたアプリケーション、環境での永続データは 以下のように分類して考え必要な物をリストアップしました。
* データベースのデータファイル、ログファイル
* 各サーバのログファイル
* 設定ファイル
* 共有ファイル



```
$ cat <<EOF | sudo tee $HOME/nginxweb3.yaml
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


pvc-nginxweb3.yaml
```
$ cat <<EOF | sudo tee $HOME/pvc-nginxweb3.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nginxweb3
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ontap-gold

EOF
```

作成したYAMLファイルを使ってPVCを作成します。
```
# kubectl apply -f pvc-nginxweb3.yaml

persistentvolumeclaim/pvc-nginxweb3 created
```


  
