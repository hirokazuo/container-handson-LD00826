# Lab4: ステートフルコンテナの実現

## 目的・ゴール: アプリケーションのデータ永続化を実現
アプリケーションは永続化領域がないとデータの保存ができません。 KubernetesではStatic provisioningとDynamic provisioningの２つの永続化の手法があります。
このレベルではDynamic provisioningを実現するためDynamic provisionerであるTridentをインストールし、 マニフェストファイルを作成しデータの永続化をすることが目標です。

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

## Dynamic provisioning
ステートフルコンテナを実現する上でストレージは重要なコンポーネントになります。

Dynamic volume provisiong はオンデマンドにストレージをプロビジョニングするためのものです。

Static provisioning、Dynamic provisioning それぞれを比較します。

Static provisioningの場合、クラスタの管理者がストレージをプロビジョニングして、PersitentVolumeオブジェクトを作成しkubernetesに公開する必要があります。

Dynamic provisioningの場合、Static provisioningで手動で行っていたステップを自動化し、管理者がおこなっていたストレージの事前のプロビジョニング作業をなくすことができます。

StorageClassオブジェクトで指定したプロビジョナを使用し、動的にストレージリソースをプロビジョニングすることができます。

StorageClassには様々なパラメータを指定することができアプリケーションに適したストレージカタログ、プロファイルを作成することができ、物理的なストレージを抽象化するレイヤとなります。

Dynamic Provisioningを実現するために ストレージを制御する Provisioner が必要になります。その標準的なインターフェースとして 2019/1からContainer Storage InterfaceがGAになり、 Kubernetes 1.14からは CSI 1.1がサポートされています。

ネットアップはDynamic provisioningを実現するためのNetApp Tridentというprovisionerを提供しています。

Tridentは CSIを使わない従来同様のTridentと CSIを使う CSI Tridentが提供されていますが、 19.07からは CSI Tridentがデフォルトでインストールされるようになりました。

このレベルではTridentでDynamic provisioningを行い、アプリケーションのデータ永続化を実現します。

## NetApp Tridentのインストール
Dynamic storage provisioningを実現するためNetApp Tridentを導入します。 TridentはPodとしてデプロイされ通常のアプリケーションと同様に稼働します。

### Trident公式ドキュメント
* https://docs.netapp.com/us-en/trident/index.html

### インストール事前準備
Trident のインストールでk8sクラスタの管理者権限が必要になります。

```
$ kubectl auth can-i '*' '*' --all-namespaces
```


バックエンドに登録するストレージのマネジメントIPにk8sクラスタのコンテナから疎通が取れるかを確認します。<br>
※本ラボ環境のONTAPストレージのマネージメントIPは`192.168.0.101`になります。
```
$ kubectl run -i --tty ping --image=busybox --restart=Never --rm --  ping [マネジメントIP]
```


### インストール
Tridentのインストール方法は複数ありますが、今回は`tridentctl`を使ってインストールします。<br>

Learn about Trident installation
* https://docs.netapp.com/us-en/trident/trident-get-started/kubernetes-deploy.html

Install using tridentctl
* https://docs.netapp.com/us-en/trident/trident-get-started/kubernetes-deploy-tridentctl.html#critical-information-about-trident-25-06

### Tridentインストール(25.06)
今回はKubernetes v1.33に対応した Trident 25.6をインストールします。
```
$ wget https://github.com/NetApp/trident/releases/download/v25.06.0/trident-installer-25.06.0.tar.gz

$ tar -xf trident-installer-25.06.0.tar.gz

$ cd trident-installer
```

Tridentの制御には `tridentctl` を使います。
また`tridentctl` ユーティリティを使ってTridentをインストールします。

`./tridentctl install -n trident`コマンドを実行します。
* `-n`オプションでTrident用のKubernetesネームスペースを指定します。

```
$ ./tridentctl install -n trident
INFO Starting Trident installation.                namespace=trident
INFO Created namespace.                            namespace=trident
INFO Created controller service account.          
INFO Created controller role.                     
INFO Created controller role binding.             
INFO Created controller cluster role.             
INFO Created controller cluster role binding.     
INFO Created node linux service account.          
INFO Creating or patching the Trident CRDs.       
INFO Applied latest Trident CRDs.                 
INFO Added finalizers to custom resource definitions. 
INFO Created Trident service.                     
INFO Created Trident encryption secret.           
INFO Created Trident protocol secret.             
INFO Created Trident resource quota.              
INFO Created Trident deployment.                  
INFO Created Trident daemonset.                   
INFO Waiting for Trident pod to start.            
INFO Trident pod started.                          deployment=trident-controller namespace=trident pod=trident-controller-6594747b-t4q9z
INFO Waiting for Trident REST interface.          
INFO Trident REST interface is up.                 version=25.06.0
INFO Trident installation succeeded.   
```
「INFO Trident installation succeeded.」が出力されればインストール成功です。



Tridentの状態を確認します。`-n`でネームスペースを指定してPodの状態を確認します。
```
# kubectl get pod -n trident

NAME                                READY   STATUS    RESTARTS   AGE
trident-controller-6594747b-t4q9z   6/6     Running   0          9m7s
trident-node-linux-gs47g            2/2     Running   0          9m7s
trident-node-linux-xqknx            2/2     Running   0          9m7s
```



もし、問題が発生した場合には tridentctl を使用してtridentに関するログをまとめて確認することが出来ます。

```
./tridentctl -n trident logs

time="2018-02-15T03:32:35Z" level=error msg="API invocation failed. Post https://10.0.1.146/servlets/netapp.servlets.admin.XMLrequest_filer: dial tcp 10.0.1.146:443: getsockopt: connection timed out"
time="2018-02-15T03:32:35Z" level=error msg="Problem initializing storage driver: 'ontap-nas' error: Error initializing ontap-nas driver. Could not determine Data ONTAP API version. Could not read ONTAPI version. Post https://10.0.1.146/servlets/netapp.servlets.admin.XMLrequest_filer: dial tcp 10.0.1.146:443: getsockopt: connection timed out" backend= handler=AddBackend
time="2018-02-15T03:32:35Z" level=info msg="API server REST call." duration=2m10.64501326s method=POST route=AddBackend uri=/trident/v1/backend
```

### Tridentのバージョン確認
Tridentのバージョンは`tridentctl version`を使って確認することができます。
```
./tridentctl version -n trident

+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 25.06.0        | 25.06.0        |
+----------------+----------------+
```

## Tridentへのバックエンド登録
Tridentが、その背後で制御するストレージ(バックエンドストレージ)を登録します。
ネットアップの各ストレージ製品ごとに必要な手順を紹介しています。
* https://docs.netapp.com/us-en/trident/trident-use/backends.html

今回はバックエンドをONTAPのNFSで接続するため、以下のドキュメントを参照します<br>
ONTAP NAS driver overview
* https://docs.netapp.com/us-en/trident/trident-use/ontap-nas.html

Prepare to configure a backend with ONTAP NAS drivers
* https://docs.netapp.com/us-en/trident/trident-use/ontap-nas-prep.html#requirements


バックエンドストレージを設定するためにjsonファイルを用意します。 サンプルファイルが`sample-input`ディレクトリにあり、ここではONTAPのNASを設定しますので`backend-ontap-nas.json`をコピーして使います。
<br>

`sample-input`ディレクトリ配下の`ontap-nas`ディレクトリに移動します。
```
$ cd ./sample-input/backends-samples/ontap-nas
```

`backend-ontap-nas.json`ファイルがあることを確認します。
```
$ ls
backend-ontap-nas-advanced.json       backend-tbc-ontap-nas-advanced.yaml
backend-ontap-nas-autoexport.json     backend-tbc-ontap-nas-autoexport.yaml
backend-ontap-nas.json                backend-tbc-ontap-nas-virtual-pools.yaml
backend-ontap-nas-virtual-pools.json  backend-tbc-ontap-nas.yaml
```

`backend-ontap-nas.json`を`trident-installer`ディレクトリにコピーします。
```
$cp backend-ontap-nas.json $HOME/trident-installer/backend-ontap-nas.json
```

コピーした`trident-installer`ディレクトリ内の`backend-ontap-nas.json`ファイルを確認します。
```
cat backend-ontap-nas.json
{
    "version": 1,
    "storageDriverName": "ontap-nas",
    "backendName": "customBackendName",
    "managementLIF": "10.0.0.1",
    "dataLIF": "10.0.0.2",
    "svm": "trident_svm",
    "username": "cluster-admin",
    "password": "password"
}
```

`backend-ontap-nas.json`ファイルを今回のLOD環境に合わせて編集します。
* backendName: **任意の名前**
* managementLIF: **192.168.0.101**
* dataLIF: **192.168.0.121**
* svm: **svm1**
* username: **admin**
* password: **Netapp1!**


## StorageClassの定義
Manage storage classes
https://docs.netapp.com/us-en/trident/trident-use/manage-stor-class.html

StorageClassを定義して、ストレージのサービスカタログを作ります。

TridentではStorageClassを作成するときに以下の属性を設定できます。 
これらの属性のパラメータを組み合わせてストレージサービスをデザインします。

### StorageClass の parameters に設定可能な属性
| 設定可能な属性                               | 例                                                                                         | 
| -------------------------------------------- | ------------------------------------------------------------------------------------------ | 
| 性能に関する属性                             | メデイアタイプ(hdd, hybrid, ssd)、プロビジョニングのタイプ（シン、シック)、IOPS            | 
| データ保護・管理に関する属性                 | スナップショット有無、クローニング有効化、暗号化の有効化                                   | 
| バックエンドのストレージプラットフォーム属性 | ontap-nas, ontap-nas-economy, ontap-nas-flexgroup, ontap-san, solidfire-san, eseries-iscsi | 

全てのパラメータ設定については以下のURLに記載があります。
* https://docs.netapp.com/us-en/trident/trident-reference/objects.html

### NFSバックエンドのONTAPでのStorageClass
今回の環境ではSVMに高速なSSDのアグリゲートが割り当てられています。
まずは高速なストレージ領域用のStorageClassを作成するためのYAMLファイルを作成します。
* ファイル名: StorageClassFastest.yaml
* tridentctlと同じ階層にYAMLファイルを作成

以下は上記の高速なストレージ領域用のStorageClass作成方法のサンプルです。

高速ストレージ用のマニフェストファイル例 StorageClassFastest.yaml
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ontap-gold
provisioner: netapp.io/trident
reclaimPolicy: Retain
parameters:
  backendType: "ontap-nas"
  media: "ssd"
  provisioningType: "thin"
  snapshots: "true"
```

つづいて、ストレージクラスを作成します。
```
# kubectl apply -f StorageClassFastest.yaml

storageclass.storage.k8s.io/ontap-gold created
```

作成したストレージクラスを確認します
```
# kubectl get sc
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
ontap-gold (default)   csi.trident.netapp.io   Delete          Immediate           false                  10s
```

（補足）
デフォルトのStorageClassの設定<br>
StorageClassは記載がないときに使用するStorageClassを指定できます。
```
kubectl patch storageclass ストレージクラス名 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Persistent Volume Claimの作成
アプリケーションで必要とされる永続化領域の定義をします。 PVCを作成時に独自の機能を有効化することができます。<br>
データの保管ポリシー、データ保護ポリシー、SnapShotの取得ポリシー、クローニングの有効化、暗号化の有効化などを設定できます。

Tridentが正しくPVをプロビジョニングできるか確認するためにPVCを作成します。
以下のPVCを作成するためのYAMLファイルを作成してください。

* ファイル名: pvctest.yaml.yaml
* tridentctlと同じ階層にYAMLファイルを作成

動作確認用 pvctest.yaml
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvctest
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ontap-gold
```

作成したYAMLファイルを使ってPVCを作成します。
```
# kubectl apply -f pvctest.yaml

persistentvolumeclaim/pvctest created
```

作成したPVCを確認します。
以下のようにSTATUSがBoundになっていれば成功です。
```
# kubectl get pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvctest   Bound    pvc-ca9d0b07-7e1a-4903-8546-79d6081f7bcc   1Gi        RWO            ontap-gold     <unset>                 40s
```

続いてPVCによって作成されたPVを確認します。先程の`kubectl get pvc`の出力と見比べてみてください。
```
# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-ca9d0b07-7e1a-4903-8546-79d6081f7bcc   1Gi        RWO            Delete           Bound    default/pvctest   ontap-gold     <unset>                          101s
```


## Snapshotの作成
TridentのSnapshotに関する利用方法は以下URLに記載されています。
<br>
Work with snapshots
* https://docs.netapp.com/us-en/trident/trident-use/vol-snapshots.html

### ボリュームスナップショットコントローラをデプロイ
今回作成したKubernetes環境にはスナップショットコントローラとCRDが含まれていないため、以下ドキュメントの記述に従って設定します。
<br>

Deploy a volume snapshot controller
* https://docs.netapp.com/us-en/trident/trident-use/vol-snapshots.html#deploy-a-volume-snapshot-controller

#### snapshot CDRを作成します。

上記ドキュメントではスクリプトファイルを作成していますが、以下、3つのコマンドを直接実行します。
```
# kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.1/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml

# kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.1/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml

# kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.1/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
```

#### snapshot controllerを作成します
ドキュメントに記載のコマンドを実行します。
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.1/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.1/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
```

### VolumeSnapshotClassを作成
スナップショットを作成するには 'VolumeSnapshotClass' を管理者が定義する必要があります。
<br>
VolumeSnapshotClassについては以下に説明があります。
Kubernetes VolumeSnapshotClass objects
* https://docs.netapp.com/us-en/trident/trident-reference/objects.html#kubernetes-attributes
Create a volume snapshot
* https://docs.netapp.com/us-en/trident/trident-use/vol-snapshots.html#create-a-volume-snapshot

ドライバーは、csi-snapclass クラスのボリューム スナップショットのリクエストが Trident によって処理されることを Kubernetes に指定します。削除ポリシーは、スナップショットが削除される際に実行されるアクションを指定します。削除ポリシーが「Delete」に設定されている場合、スナップショットが削除されると、ボリュームスナップショットオブジェクトおよびストレージクラスター上の基盤となるスナップショットが削除されます。一方、「Retain」に設定すると、VolumeSnapshotContentと物理スナップショットが保持されます。

VolumeSnapshotClassを作成するためのYAMLファイルを作成します。
* ファイル名: VolumeSnapshotClass.yaml

VolumeSnapshotClass.yaml 記述内容
```
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
driver: csi.trident.netapp.io
deletionPolicy: Delete
```

作成したYAMLファイルを使ってVolumeSnapshotClassを作成します。
```
# kubectl apply -f VolumeSnapshotClass.yaml
```

### Snapshotを作成
先に作成したPVCに対してsnapshotを作成します。

Snapshotを作成するためのYAMLファイルを作成します。
* ファイル名: snapshot-test.yaml

snapshot-test.yaml 記述内容
```
kind: VolumeSnapshot
metadata:
  name: pvctest-snap
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: pvctest
```

```
kubectl apply -f $HOME/snapshot-test.yaml
```

```
# kubectl get volumesnapshot
NAME           READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS   SNAPSHOTCONTENT   CREATIONTIME   AGE
pvctest-snap                pvctest                                           csi-snapclass                                    58s
```


https://github.com/kubernetes-csi/external-snapshotter/tree/master/client/config/crd







