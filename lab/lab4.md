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
`tridentctl` ユーティリティではドライランモードとデバッグモードがオプションで指定できます。 ２つを設定し、実行すると以下のように必要事項を事前チェックし、その内容をすべて標準出力にプリントします。

まずは、ドライランモードで実行し問題ないことを確認します。

Tridentをインストールするネームスペースを作成します。



