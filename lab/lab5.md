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




アプリケーションのデータ永続化を確認するためにハンズオンで3つ目のnginxのPodを作成します。


### PVCの作成 
nginxweb3用のPVCをデプロイします。デプロイするためのYAMLファイルを作成します。

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

nginxをデプロイするためのマニフェストを作成します。<br>
今回は34行目以下にvolumeMountsに関する記述があることを確認してください。

nginxweb3.yaml
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
        volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: nginxweb3-volume
      volumes:
        - name: nginxweb3-volume
          persistentVolumeClaim:
            claimName: pvc-nginxweb3

EOF
```

KubernetesのPod定義をYAMLで記述する際、`volumeMounts`内の`name`フィールドは重要な役割を果たします。このフィールドは、Podレベルで定義されたボリュームと特定のボリュームマウントを関連付けます。


**Volume定義**: Podの`spec.volumes`セクションで、1つまたは複数のボリュームを定義します。各ボリュームには一意の名前を付ける必要があります。この名前は、Pod内でのそのボリュームの識別子として機能します。

**Volume Mount定義**：コンテナの`spec.containers`セクション内の`volumeMounts`セクションで、そのコンテナにボリュームをマウントする方法指定します。`volumeMounts`内の`name`フィールドは、`spec.volumes`で定義されたボリュームの名前と完全に一致する必要があります。これにより、コンテナ内のマウントポイントと実際のボリュームとの接続が確立されます。
要約すると、`volumeMounts`内の名前は定義されたボリュームへの参照として機能し、コンテナが指定されたマウントパスでそのボリュームが提供するストレージにアクセスし利用できるようにします。


作成したYAMLファイルを使ってnginxのPodを作成します。
```
# kubectl apply -f nginxweb3.yaml
```

```
# kubectl apply -f nginxweb3.yaml


```



~# kubectl exec --stdin --tty nginxweb3-deployment-5f5dd7c595-4rjwm -- /bin/bash
root@nginxweb3-deployment-5f5dd7c595-4rjwm:/# 
root@nginxweb3-deployment-5f5dd7c595-4rjwm:/# 
root@nginxweb3-deployment-5f5dd7c595-4rjwm:/# 
root@nginxweb3-deployment-5f5dd7c595-4rjwm:/# 
root@nginxweb3-deployment-5f5dd7c595-4rjwm:/# 
root@nginxweb3-deployment-5f5dd7c595-4rjwm:/# df
Filesystem                                                      1K-blocks    Used Available Use% Mounted on
overlay                                                         100557880 9265016  86138664  10% /
tmpfs                                                               65536       0     65536   0% /dev
cgroup                                                               1024       0      1024   0% /sys/fs/cgroup
shm                                                                 65536       0     65536   0% /dev/shm
tmpfs                                                              813612    2976    810636   1% /etc/hostname
/dev/mapper/ubuntu--vg-ubuntu--lv                               100557880 9265016  86138664  10% /etc/hosts
192.168.0.121:/trident_pvc_bdf5a40d_a6d9_4e99_91bc_951343916eef   1048576     320   1048256   1% /usr/share/nginx/html
tmpfs                                                             8033692      12   8033680   1% /run/secrets/kubernetes.io/serviceaccount
udev                                                              4018760       0   4018760   0% /proc/keys
root@nginxweb3-deployment-5f5dd7c595-4rjwm:/# 




  
