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
my-nginx3用のPVCをデプロイします。デプロイするためのYAMLファイルを作成します。

ホームディレクトリにpvc-my-nginx3.yamlを作成
```
$ cat <<EOF | sudo tee $HOME/pvc-my-nginx3.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-my-nginx3
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
$ kubectl apply -f pvc-my-nginx3.yaml

persistentvolumeclaim/pvc-my-nginx3 created
```

```
$ kubectl get pvc

NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc-my-nginx3   Bound    pvc-615523cd-6402-48a4-9523-6456fc49f04d   1Gi        RWO            ontap-gold     <unset>                 30s
```

nginxをデプロイするためのマニフェストを作成します。<br>
今回は34行目以下にvolumeMountsに関する記述があることを確認してください。

ホームディレクトリにmy-nginx3.yamlを作成
```
cat <<EOF | sudo tee $HOME/my-nginx3.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nginx3
  labels:
    run: my-nginx3
spec:
  type: LoadBalancer
  ports:
  - port: 80
    protocol: TCP
  selector:
    run: my-nginx3
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx3
spec:
  selector:
    matchLabels:
      run: my-nginx3
  replicas: 1
  template:
    metadata:
      labels:
        run: my-nginx3
    spec:
      containers:
      - name: my-nginx3
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: my-nginx3-volume
      volumes:
        - name: my-nginx3-volume
          persistentVolumeClaim:
            claimName: pvc-my-nginx3

EOF
```

KubernetesのPod定義をYAMLで記述する際、`volumeMounts`内の`name`フィールドは重要な役割を果たします。このフィールドは、Podレベルで定義されたボリュームと特定のボリュームマウントを関連付けます。


**Volume定義**: Podの`spec.volumes`セクションで、1つまたは複数のボリュームを定義します。各ボリュームには一意の名前を付ける必要があります。この名前は、Pod内でのそのボリュームの識別子として機能します。

**Volume Mount定義**：コンテナの`spec.containers`セクション内の`volumeMounts`セクションで、そのコンテナにボリュームをマウントする方法指定します。`volumeMounts`内の`name`フィールドは、`spec.volumes`で定義されたボリュームの名前と完全に一致する必要があります。これにより、コンテナ内のマウントポイントと実際のボリュームとの接続が確立されます。
要約すると、`volumeMounts`内の名前は定義されたボリュームへの参照として機能し、コンテナが指定されたマウントパスでそのボリュームが提供するストレージにアクセスし利用できるようにします。


作成したYAMLファイルを使ってnginxのPodを作成します。
```
$ kubectl apply -f my-nginx3.yaml

service/my-nginx3 created
deployment.apps/my-nginx3-deployment created

```

Podの状態を確認します。
```
$ kubectl get pod

NAME                                    READY   STATUS    RESTARTS   AGE
my-nginx3-deployment-5f5dd7c595-q6vhh   1/1     Running   0          48s
```



nginxコンテナへのシェルの取得します。
```
$ kubectl exec --stdin --tty my-nginx3-deployment-5f5dd7c595-q6vhh -- /bin/bash
```

コンテナ内にTridentが作成したボリュームがマウントされていることを確認します。
```
(コンテナ内のシェルで実行します)
root@my-nginx3-deployment-5f5dd7c595-q6vhh:/# df -h

Filesystem                                                       Size  Used Avail Use% Mounted on
overlay                                                           96G  8.5G   83G  10% /
tmpfs                                                             64M     0   64M   0% /dev
cgroup                                                           1.0M     0  1.0M   0% /sys/fs/cgroup
shm                                                               64M     0   64M   0% /dev/shm
tmpfs                                                            796M  3.1M  793M   1% /etc/hostname
/dev/mapper/ubuntu--vg-ubuntu--lv                                 96G  8.5G   83G  10% /etc/hosts
192.168.0.121:/trident_pvc_615523cd_6402_48a4_9523_6456fc49f04d  1.0G  256K  1.0G   1% /usr/share/nginx/html
tmpfs                                                            7.7G   12K  7.7G   1% /run/secrets/kubernetes.io/serviceaccount
udev                                                             3.9G     0  3.9G   0% /proc/keys
```

nginxのドキュメントルートにテスト用のファイルを作成します。
```
(コンテナ内のシェルで実行します)
root@my-nginx3-deployment-5f5dd7c595-4rjwm:/# cat <<EOF | tee /usr/share/nginx/html/test.html
<html>
	<head>
	<title>
		NGINX TEST
	</title>
	</head>

	<body>
		Hands on lab test
	</body>
</html>

EOF
```

nginxのコンテナからExitします。
```
(コンテナ内のシェルで実行します)
root@my-nginx3-deployment-5f5dd7c595-4rjwm:/# exit
```

nginxにアクセスするためのIPアドレスを確認します。
```
$ kubectl get svc

NAME              TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
my-nginx3         LoadBalancer   10.109.105.180   192.168.0.223   80:31466/TCP   3m37s
```

プラウザで確認したアドレスを使ってnginxコンテナ内に作成したテストページにアクセスします。
* （例）http://192.168.0.223/test.html



nginxのPodを削除します。
```
$ kubectl delete pod my-nginx3-deployment-5f5dd7c595-q6vhh

pod "my-nginx3-deployment-5f5dd7c595-q6vhh" deleted
```

nginxのPodの状態を確認します
```
$ kubectl get pod

NAME                                    READY   STATUS    RESTARTS   AGE
my-nginx3-deployment-5f5dd7c595-qpnv7   1/1     Running   0          27s
```
Podの名前が変わって新たに作成されていることが確認できます。


再度nginxコンテナ内に作成したテストページにアクセスします。
* （例）http://192.168.0.223/test.html

余裕があればnginxコンテナへのシェルからtest.htmlがコンテナ内のnginxドキュメントルートの残っていることを確認してください。


Kubenetesノード上でのボリュームを確認します。Ubuntuホスト上でdfコマンドを実行します。
```
(mgmt01 上で実行)
$ df -h |grep trident

192.168.0.121:/trident_pvc_bdf5a40d_a6d9_4e99_91bc_951343916eef  1.0G  320K  1.0G   1% /var/lib/kubelet/pods/30ed1ae0-e2f1-42a3-916b-b9f3bf3d2605/volumes/kubernetes.io~csi/pvc-bdf5a40d-a6d9-4e99-91bc-951343916eef/mount
```
ボリュームはコンテナがマウントしているのではなく、Kubernetesのノードがマウントしていることが確認できます。



### クローンの作成(1): VolumeSnapshotからPVCを作成
nginx用に永続化したボリュームのクローンを作成します。

まず、PVCのスナップショットを作成します。

```
cat <<EOF | sudo tee $HOME/volumesnapshot-pvc-my-nginx3.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: pvc-my-nginx3-snap
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: pvc-my-nginx3
EOF
```

作成したYAMLファイルを使ってVolumeSnapshoptを作成します。
```
$ kubectl apply -f $HOME/volumesnapshot-pvc-my-nginx3.yaml

volumesnapshot.snapshot.storage.k8s.io/pvc-my-nginx3-snap created
```

VolumeSnapshoptの状態を確認します。
```
$ kubectl get volumesnapshot

NAME                 READYTOUSE   SOURCEPVC       SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS   SNAPSHOTCONTENT                                    CREATIONTIME   AGE
pvc-my-nginx3-snap   true         pvc-my-nginx3                           292Ki         csi-snapclass   snapcontent-5422404a-574f-4736-86a6-556eabb26f8c   44s            40s
```


スナップショットからPVCを作成するためのマニフェストを作成します。

pvc-from-snap.yamlを以下の内容で作成してください
```
cat <<EOF | sudo tee $HOME/pvcclone-from-snap.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvcclone-from-snap
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ontap-gold
  resources:
    requests:
      storage: 10Gi
  dataSource:
    name: pvc-my-nginx3-snap
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
EOF
```

作成したYAMLファイルを使ってスナップショットからPVCをデプロイします。
```
$ kubectl apply -f pvcclone-from-snap.yaml

persistentvolumeclaim/pvc-from-snap created
```

PVCの状態を確認します。
```
$ kubectl get pvc

NAME            STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc-from-snap   Pending                                                                        ontap-gold     <unset>                 14s
pvc-my-nginx3   Bound     pvc-2d09720e-ba3c-498c-ab01-98555a76042f   1Gi        RWO            ontap-gold     <unset>                 5m58s
```
PVC `pvc-from-snap`の状態が `Pending`になっています。
<br>

原因を確認するため、PVC `pvc-from-snap`リソースの割当状況を確認してください。
```
$ kubectl describe pvc pvc-from-snap
```
コマンドの出力から何が確認できるでしょうか？
先に作成した `pvc-from-snap.yaml` のどこが間違っているでしょうか？

 `pvc-from-snap.yaml` の修正内容がわかったら修正してください。
修正したマニフェストを使って pvc-from-snapをデプロイする前にPending状態のpvc-from-snapを削除します。
```
$ kubectl delete pvc pvc-from-snap

persistentvolumeclaim "pvc-from-snap" deleted
```

修正したマニフェストを使って pvc-from-snapをデプロイします。
```
$ kubectl apply -f pvc-from-snap.yaml

persistentvolumeclaim/pvc-from-snap created
```

PVCの状態を確認します。
```
kubectl get pvc
NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc-from-snap   Bound    pvc-5346dbec-b53f-444f-a267-d6a0efe49b39   1Gi        RWO            ontap-gold     <unset>                 11s
pvc-my-nginx3   Bound    pvc-2d09720e-ba3c-498c-ab01-98555a76042f   1Gi        RWO            ontap-gold     <unset>                 14m
```


### クローンの作成(2): PVCから直接クローン
nginx用に永続化したボリュームのクローンを作成します。
今回はオリジナルのPVCである`pvc-my-nginx3`から作成します。

```
cat <<EOF | sudo tee $HOME/clone-from-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-from-pvc-my-nginx3
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: ontap-gold
  resources:
    requests:
      storage: 1Gi
  dataSource:
    kind: PersistentVolumeClaim
    name: pvc-my-nginx3
    
EOF
```

作成したYAMLファイルを使ってスナップショットからPVCをデプロイします。
```
$ kubectl apply -f clone-from-pvc.yaml

persistentvolumeclaim/pvc-from-pvc-my-nginx3 created
```


PVCの状態を確認します。
```
$ kubectl get pvc

NAME                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc-from-pvc-my-nginx3   Bound    pvc-ebfa082d-07c7-4807-ab32-1c98a367a221   1Gi        RWO            ontap-gold     <unset>                 79s
pvc-from-snap            Bound    pvc-adcbf77e-4bbe-4d3a-929d-5624fadc1d5c   1Gi        RWO            ontap-gold     <unset>                 5m56s
pvc-my-nginx3            Bound    pvc-615523cd-6402-48a4-9523-6456fc49f04d   1Gi        RWO            ontap-gold     <unset>                 63m
```



### クローンしたPVCにアプリケーションから接続
新たなnginexWebサーバにクローンしたPVCをマウントします。
* マニフェスト名: my-nginx4.yaml
* Pod名: my-nginx4
* PVC: pvc-from-pvc-my-nginx3

このセクションはどうやって実現するかを考えていただくためあえて答えは書いてありません。

作成したYAMLファイルを使ってmy-nginx4をデプロイします。
```
$ kubectl apply -f my-nginx4.yaml

service/my-nginx4 created
deployment.apps/my-nginx4-deployment created
```

my-nginx4のExternal-IPを確認します
```
$ kubectl get svc

NAME              TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
my-nginx4         LoadBalancer   10.104.163.225   192.168.0.224   80:30292/TCP   74s
```

ブラウザからmy-nginx4にアクセスしてmy-nginx3で作成したテスト用のHTMLにアクセスできることを確認します。
* （例）http://192.168.0.224/test.html

<br>
<br>
<br>
Lab5は以上となります。










  
