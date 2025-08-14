#!/bin/bash

# このすスクリプトはjumphost上で実行します

# -------------------------------------------------------
# SSHコマンドの警告メッセージを抑止
# -------------------------------------------------------
# rm -f /home/user/.ssh/known_hosts
cat <<EOF | sudo tee -a /etc/ssh/ssh_config
StrictHostKeyChecking no
EOF

# -------------------------------------------------------
# k8sadminホストをクリーンアップ
# Jumphost上でクリーンアップ用スクリプト(LD00826_cleanup_k8sadmin.sh)を作成
# Jumphostからk8sadminにスクリプトをscpでコピー
# sshを使ってk8sadmin上でスクリプトを実行
# -------------------------------------------------------
cat << EOL > $HOME/LD00826_cleanup_k8sadmin.sh
#!/bin/bash

# sudoの権限を設定
sudo cat << EOF | sudo tee -a /etc/sudoers
user ALL=NOPASSWD: ALL
EOF

# remove existing files
sudo rm -rf /home/user/.kube/
sudo rm -f /usr/local/bin/kubectl

# reset iptables
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t raw -F 
sudo iptables -t raw -X
sudo iptables -t mangle -F 
sudo iptables -t mangle -X

sudo reboot

EOL

chmod +x $HOME/LD00826_cleanup_k8sadmin.sh

# clean up k8sadmin host
scp $HOME/LD00826_cleanup_k8sadmin.sh user@k8sadmin:$HOME/LD00826_cleanup_k8sadmin.sh
ssh -t user@k8sadmin $HOME/LD00826_cleanup_k8sadmin.sh


# -------------------------------------------------------
# mgmt01ホストをクリーンアップ
# Jumphost上でクリーンアップ用スクリプト(LD00826_cleanup_mgmt01.sh)を作成
# Jumphostからmgmt01にスクリプトをscpでコピー
# sshを使ってmgmt01上でスクリプトを実行
# -------------------------------------------------------
cat << EOL > $HOME/LD00826_cleanup_mgmt01.sh
#!/bin/bash

# sudoの権限を設定
sudo cat << EOF | sudo tee -a /etc/sudoers
user ALL=NOPASSWD: ALL
EOF

sudo docker login

# Reset exisiting kubernetes
sudo kubeadm reset -f

# sudo apt-get -y purge kubectl kubeadm kubelet kubernetes-cni

# remove existing files
sudo rm -rf /var/lib/etcd
sudo rm -rf /etc/cni/net.d
sudo rm -rf /etc/kubernetes
sudo rm -rf /root/kube-manifests
sudo rm -rf /root/.kube
sudo rm -rf /root/.helm
sudo rm -f /usr/local/bin/kubeadm
sudo rm -f /usr/local/bin/kubectl
sudo rm -f /usr/local/bin/kubelet
sudo rm -f /usr/local/bin/helm
sudo rm -f /root/kubeadm.conf 
sudo rm -rf /usr/local/bin/*
sudo rm -rf /opt/cni/
sudo rm -rf /var/log/calico
sudo rm -rf /var/lib/calico
sudo rm -rf /etc/ssl/etcd
sudo rm -rf /var/lib/etcd


# reset iptables
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t raw -F 
sudo iptables -t raw -X
sudo iptables -t mangle -F 
sudo iptables -t mangle -X

#reset system's IPVS tables.
sudo ipvsadm --clear 

# Remove docker
sudo apt-mark unhold docker*
sudo apt-mark unhold containerd*
sudo apt-get purge -y docker*
sudo apt-get purge -y containerd.io

sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/dockershim
sudo rm -rf /var/lib/containerd
sudo rm -rf /usr/local/bin/docker-compose
sudo rm -rf /etc/docker
sudo groupdel docker

sudo reboot

EOL


chmod +x $HOME/LD00826_cleanup_mgmt01.sh

# clean up mgmt01 host
scp $HOME/LD00826_cleanup_mgmt01.sh root@mgmt01:/root/LD00826_cleanup_mgmt01.sh
ssh root@mgmt01 "/root/LD00826_cleanup_mgmt01.sh > cleanup.log 2>&1 &"


# -------------------------------------------------------
# Clean up gpu01
# Jumphost上でクリーンアップ用スクリプト(LD00826_cleanup_gpu01.sh)を作成
# Jumphostからgpu01にスクリプトをscpでコピー
# sshを使ってgpu01上でスクリプトを実行
# -------------------------------------------------------
cat << EOL > $HOME/LD00826_cleanup_gpu01.sh
#!/bin/bash

# sudoの権限を設定
sudo cat << EOF | sudo tee -a /etc/sudoers
user ALL=NOPASSWD: ALL
EOF

sudo docker login

# Remove k8s and NetApp Trident
sudo kubeadm reset -f

# 
# sudo apt -y purge kubectl kubeadm kubelet kubernetes-cni

sudo rm -rf /var/lib/etcd
sudo rm -rf /etc/cni/net.d
sudo rm -rf /etc/kubernetes
sudo rm -rf /root/kube-manifests
sudo rm -rf /root/.kube
sudo rm -rf /root/.helm
sudo rm -f /usr/local/bin/kubeadm
sudo rm -f /usr/local/bin/kubectl
sudo rm -f /usr/local/bin/kubelet
sudo rm -f /usr/local/bin/helm
sudo rm -f /root/kubeadm.conf 
sudo rm -rf /usr/local/bin/*
sudo rm -rf /opt/cni/
sudo rm -rf /var/log/calico
sudo rm -rf /var/lib/calico
sudo rm -rf /etc/ssl/etcd
sudo rm -rf /var/lib/etcd

# reset iptables
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t raw -F 
sudo iptables -t raw -X
sudo iptables -t mangle -F 
sudo iptables -t mangle -X

# Remove docker
sudo apt-mark unhold docker*
sudo apt-mark unhold containerd*
sudo apt-get purge -y docker*
sudo apt-get purge -y containerd.io

sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/dockershim
sudo rm -rf /var/lib/containerd
sudo rm -rf /usr/local/bin/docker-compose
sudo rm -rf /etc/docker
sudo groupdel docker

reboot

EOL

chmod +x $HOME/LD00826_cleanup_gpu01.sh

# clean up gpu01 host
scp $HOME/LD00826_cleanup_gpu01.sh root@gpu01:/root/LD00826_cleanup_gpu01.sh
ssh root@gpu01 "/root/LD00826_cleanup_gpu01.sh > cleanup.log 2>&1 &"


# -------------------------------------------------------
# ラボ環境のクリーンアップが終わるまで3分待ちます
# -------------------------------------------------------
echo ラボ環境のクリーンアップが終わるまで3分待ちます

function countDown() {
  start=1
  end=180
  echo "please wait $end seconds"
  while [[ $start -le $end ]]; do
    echo $(($end-$start))
    sleep 1
    start=$(($start+1))
  done
}

countDown

echo -e "ラボ環境のクリーンアップが終わりました\n続いてkubernatesクラスタ マスターノードのセットアップをおこないます"

