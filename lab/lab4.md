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

### インストール事前準備
Trident のインストールでk8sクラスタの管理者権限が必要になります。

```
$ kubectl auth can-i '*' '*' --all-namespaces
```


バックエンドに登録するストレージのマネジメントIP（配布資料のsvmXXのIPアドレス）にk8sクラスタのコンテナから疎通が取れるかを確認します。
```
$ kubectl run -i --tty ping --image=busybox --restart=Never --rm --  ping [マネジメントIP]
```


### Tridentインストール(19.07〜)
バイナリをダウンロードしてインストールします。(例はバージョン19.07.0)
```
$ wget https://github.com/NetApp/trident/releases/download/v19.07.0/trident-installer-19.07.0.tar.gz

$ tar -xf trident-installer-19.07.0.tar.gz

$ cd trident-installer
```

Tridentの制御には `tridentctl` を使います。
`tridentctl` ユーティリティではドライランモードとデバッグモードがオプションで指定できます。 
２つを設定し、実行すると以下のように必要事項を事前チェックし、その内容をすべて標準出力にプリントします。

まずは、ドライランモードで実行し問題ないことを確認します。
Tridentをインストールするネームスペースを作成します。

```
$ kubectl create ns trident

namespace/trident created
```


Tridentのインストーラーをドライランモードで実行します。

```
$ ./tridentctl install --dry-run -n trident -d

DEBU Initialized logging.                          logLevel=debug
DEBU Running outside a pod, creating CLI-based client.
DEBU Initialized Kubernetes CLI client.            cli=kubectl flavor=k8s namespace=default version=1.11.0
DEBU Validated installation environment.           installationNamespace=trident kubernetesVersion=
DEBU Parsed requested volume size.                 quantity=2Gi
DEBU Dumping RBAC fields.                          ucpBearerToken= ucpHost= useKubernetesRBAC=true
DEBU Namespace does not exist.                     namespace=trident
DEBU PVC does not exist.                           pvc=trident
DEBU PV does not exist.                            pv=trident
- snip
INFO Dry run completed, no problems found.
- snip
```

ドライランモードで実施すると問題ない旨(INFO Dry run completed, no problems found.) が表示されれば、インストールに必要な事前要件を満たしていることが確認できます。 バージョン、実行モードによってはログの途中に出力されることもあるためログを確認しましょう。

上記の状態まで確認できたら実際にインストールを実施します。

```
$ ./tridentctl install -n trident -d

DEBU Initialized logging.                          logLevel=debug
DEBU Running outside a pod, creating CLI-based client.
DEBU Initialized Kubernetes CLI client.            cli=kubectl flavor=k8s namespace=default version=1.11.0
DEBU Validated installation environment.           installationNamespace=trident kubernetesVersion=
DEBU Parsed requested volume size.                 quantity=2Gi
DEBU Dumping RBAC fields.                          ucpBearerToken= ucpHost= useKubernetesRBAC=true
DEBU Namespace does not exist.                     namespace=trident
DEBU PVC does not exist.                           pvc=trident
DEBU PV does not exist.                            pv=trident
- snip
INFO Trident installation succeeded.
```

「INFO Trident installation succeeded.」が出力されればインストール成功です。

また、問題が発生した場合には tridentctl を使用してtridentに関するログをまとめて確認することが出来ます。


```
./tridentctl -n trident logs

time="2018-02-15T03:32:35Z" level=error msg="API invocation failed. Post https://10.0.1.146/servlets/netapp.servlets.admin.XMLrequest_filer: dial tcp 10.0.1.146:443: getsockopt: connection timed out"
time="2018-02-15T03:32:35Z" level=error msg="Problem initializing storage driver: 'ontap-nas' error: Error initializing ontap-nas driver. Could not determine Data ONTAP API version. Could not read ONTAPI version. Post https://10.0.1.146/servlets/netapp.servlets.admin.XMLrequest_filer: dial tcp 10.0.1.146:443: getsockopt: connection timed out" backend= handler=AddBackend
time="2018-02-15T03:32:35Z" level=info msg="API server REST call." duration=2m10.64501326s method=POST route=AddBackend uri=/trident/v1/backend
```

### Tridentのバージョン確認







