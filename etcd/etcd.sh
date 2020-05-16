#!/bin/bash


#path=$(cd `dirname $0`;pwd)
#conf_dir="$path/config/etcd/"
#echo $conf_dir
#cd $conf_dir
CERT_DIR=/etc/etcd/ssl/
SVC_DIR=/usr/lib/systemd/system/etcd.service 
ETCD_NAME=node2
INTERNAL_IP=(192.168.2.5 192.168.2.4 192.168.2.2)
WK_DIR=/var/lib/etcd/

genCert(){
echo "genrate cert ..."
  cfssl gencert -initca ca-csr.json | cfssljson -bare ca
  
  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=aspire etcd-csr.json | cfssljson -bare etcd
  #cd -
  
  
  if [ ! -d "$CERT_DIR" ];then
   echo "mk dir cert..."
    mkdir $CERT_DIR
  fi
  
  mv *.pem $CERT_DIR
  
  ls -al $CERT_DIR
  
  rm -rf $WK_DIR
  
  if [ ! -d "$WK_DIR" ];then
    echo "mk var lib etcd $WK_DIR"
    mkdir -p $WK_DIR
  fi
  
  scp  -r /etc/etcd/ssl/ root@node1:/etc/etcd/
  scp  -r /etc/etcd/ssl/ root@node2:/etc/etcd/
  scp  -r /etc/etcd/ssl/ root@node3:/etc/etcd/
}

createSvc(){
for ip in ${INTERNAL_IP[@]};do
cat >$SVC_DIR<<EOF
[Unit]
Description=etcd server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WorkingDirectory=${WK_DIR} 
EnvironmentFile=-/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd \
--name ${ETCD_NAME} \
--cert-file=/etc/etcd/ssl/etcd.pem \
--key-file=/etc/etcd/ssl/etcd-key.pem \
--peer-cert-file=/etc/etcd/ssl/etcd.pem \
--peer-key-file=/etc/etcd/ssl/etcd-key.pem \
--trusted-ca-file=/etc/etcd/ssl/ca.pem \
--peer-trusted-ca-file=/etc/etcd/ssl/ca.pem \
--initial-advertise-peer-urls https://${ip}:2380 \
--listen-peer-urls https://${ip}:2380,https://127.0.0.1:2380 \
--listen-client-urls https://${ip}:2379,https://127.0.0.1:2379 \
--advertise-client-urls https://${ip}:2379,https://127.0.0.1:2379 \
--initial-cluster-token etcd-cluster-1 \
--initial-cluster master=https://192.168.2.2:2380,node2=https://192.168.2.5:2380,node1=https://192.168.2.4:2380 \
--initial-cluster-state new \
--data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
  if [ $ip = "192.168.2.5" ]; then
    ETCD_NAME=node1
    scp  $SVC_DIR root@node2:$SVC_DIR
    echo "copy $ip"
  fi
  
  if [ $ip = "192.168.2.4" ]; then
    ETCD_NAME=master
    scp  $SVC_DIR root@node1:$SVC_DIR
    echo "copy $ip"
  fi
  
  echo $ETCD_NAME
  
  done
}

start(){
  systemctl daemon-reload
  systemctl enable etcd
  systemctl start etcd
}

bootstrap(){
  for ip in ${INTERNAL_IP[@]};do
  echo $ip
  
  if [ $ip != "192.168.2.2" ]; then
    ssh -t -t root@$ip <<remotessh
    ps aux|grep etcd|awk -F " " '/^etcd/{print \$2}'|xargs -r kill -9
    rm -rf $WK_DIR
    mkdir -p $WK_DIR
    systemctl daemon-reload
    systemctl enable etcd
    systemctl start etcd
    exit
remotessh
  else
    start
  fi
  done
}
clean(){
   systemctl stop etcd;ps aux|grep etcd|awk  '/^etcd/{print $2}'|xargs -r kill -9;rm -f  /usr/lib/systemd/system/etcd.service;rm -rf /etc/etcd/ssl

 for ip in ${INTERNAL_IP[@]};do
  echo $ip

  if [ $ip != "192.168.2.2" ]; then
    ssh -t -t root@$ip <<remotessh
systemctl stop etcd;ps aux|grep etcd|awk  '/^etcd/{print $2}'|xargs -r kill -9;rm -f  /usr/lib/systemd/system/etcd.service;rm -rf /etc/etcd/ssl;exit;
remotessh
fi
done
echo "clean done"
}

setup(){
  clean
  #exit
  genCert
  createSvc
  bootstrap
}

case $1 in
 "c")
   clean
  ;;
  *)
  setup
esac
