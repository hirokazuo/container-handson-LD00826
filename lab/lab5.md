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
  name: nginxweb3
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
  name: nginxweb3-deployment
spec:
  selector:
    matchLabels:
      run: nginx
  replicas: 1
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

作成したYAMLファイルを使ってPVCを作成します。
```
# kubectl apply -f nginxweb3.yaml

service/nginxweb3 created
deployment.apps/nginxweb3-deployment created
```

```
# kubectl get pod

NAME                                    READY   STATUS    RESTARTS   AGE
nginxweb3-deployment-8564df9445-mjw6v   1/1     Running   0          2m39s
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

```
# kubectl get pvc
NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc-nginxweb3   Bound    pvc-bdf5a40d-a6d9-4e99-91bc-951343916eef   1Gi        RWO            ontap-gold     <unset>                 19s
```

34行目以下にvolumeMountsに関する記述を追記します。
pvc-nginxweb3.yamlを更新
```
apiVersion: v1
kind: Service
metadata:
  name: nginxweb3
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
  name: nginxweb3-deployment
spec:
  selector:
    matchLabels:
      run: nginx
  replicas: 1
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
        volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: nginxweb3-volume
      volumes:
        - name: nginxweb3-volume
          persistentVolumeClaim:
            claimName: pvc-nginxweb3
```

KubernetesのPod定義をYAMLで記述する際、`volumeMounts`内の`name`フィールドは重要な役割を果たします。このフィールドは、Podレベルで定義されたボリュームと特定のボリュームマウントを関連付けます。


**Volume定義**: Podの`spec.volumes`セクションで、1つまたは複数のボリュームを定義します。各ボリュームには一意の名前を付ける必要があります。この名前は、Pod内でのそのボリュームの識別子として機能します。

**Volume Mount定義**：コンテナの`spec.containers`セクション内の`volumeMounts`セクションで、そのコンテナにボリュームをマウントする方法指定します。`volumeMounts`内の`name`フィールドは、`spec.volumes`で定義されたボリュームの名前と完全に一致する必要があります。これにより、コンテナ内のマウントポイントと実際のボリュームとの接続が確立されます。
要約すると、`volumeMounts`内の名前は定義されたボリュームへの参照として機能し、コンテナが指定されたマウントパスでそのボリュームが提供するストレージにアクセスし利用できるようにします。



  
