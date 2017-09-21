#!/bin/bash

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -m|--master)
    MASTER_IP="$2"
    shift # past argument
    ;;
    -h|--host)
    MY_HOST_IP="$2"
    shift # past argument
    ;;
    -t|--test)
    TESTMODE=1
    shift # past argument
    ;;
    *)
       echo "invalid args"
       exit 1
    ;;
esac
shift # past argument or value
done


function main {
    set -e  # abort on failure
    echo "======= PROVISIONING (Master) =========="
    #getenvs
    apt-refresh
    install-docker
    install-kubernetes
    start-master
    settup-nonpriv
    settup-flannel
    settup-dashboard

    echo "======= PROVISIONING COMPLETE =========="
}

#function getenvs {
#    # Grab HOSTIP going to need it later
#    #MY_HOST_IP=`ip -o -4 addr show scope global | awk -F '[ /]+' '/eth0/ {print $4}'`
#    #MY_HOST_IP="10.0.3.101"
#}

function apt-refresh {
    # Refresh debian install and minimum extra packages
    echo "======= apt refresh ==========="
    apt-get update
    apt-get upgrade -y
}


function install-docker {
    echo "======= install docker ==========="
    apt-get install -y docker.io
}


function install-kubernetes {
    echo "======= install kubernetes =========="
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y --allow-unauthenticated kubelet kubeadm kubectl kubernetes-cni

}

function start-master {
    echo "======= start master ========"
    kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address $MASTER_IP

}

function settup-nonpriv {
    echo "======= settup non-prived user ======="
    mkdir -p /home/ubuntu/.kube
    cp -i /etc/kubernetes/admin.conf  /home/ubuntu/.kube/config
    chown -R ubuntu:ubuntu  /home/ubuntu/.kube
}

function settup-flannel {
    echo "======= settup flannel  ======="
    su -lc "kubectl create -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml --namespace=kube-system" ubuntu
    su -lc "kubectl create -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml --namespace=kube-system" ubuntu
}

function settup-dashboard {
    echo "======= settup dashboard  ======="
    su -lc "kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/influxdb.yaml" ubuntu
    su -lc "kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/grafana.yaml" ubuntu
    su -lc "kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/heapster.yaml" ubuntu
    su -lc "kubectl create -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/kubernetes-dashboard/v1.6.3.yaml" ubuntu
    su -lc "kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml" ubuntu

    # "special" LB proxy service so we can see it externally on http://masterip:30888
    su -lc "kubectl create -f /vagrant/kuberdashboard3.yaml" ubuntu


}







#-----MAIN---------------------------------------------------------


if [ $TESTMODE ]
then
    echo "Test mode functions defined only."
else
    main
fi