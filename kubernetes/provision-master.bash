#!/bin/bash

while [[ $# -ge 1 ]]
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
    ;;
    -p|--post)
    POSTMODE=1
    ;;
    *)
       echo "invalid args"
       exit 1
    ;;
esac
shift # past argument or value
done

echo "IP $MASTER_IP"
echo "HOST $MY_HOST_IP"
echo "TEST $TESTMODE"
echo "POST $POSTMODE"

USERNAME=vagrant


function main {
    set -e  # abort on failure
    echo "======= PROVISIONING (Master) =========="
    #getenvs
    apt-refresh
    install-docker
    install-kubernetes
    start-master
    settup-nonpriv
    # Pause here to let kubernetes stabilise ( # TODO: proper waitstable )
    sleep 60
    settup-flannel
   # settup-dashboard

    echo "======= PROVISIONING COMPLETE =========="
}

function postmode {
    echo "==== executing post mode commands ===="
    settup-flannel
    settup-dashboard
}

#function getenvs {
#    # Grab HOSTIP going to need it later
#    #MY_HOST_IP=`ip -o -4 addr show scope global | awk -F '[ /]+' '/eth0/ {print $4}'`
#    #MY_HOST_IP="10.0.3.101"
#}

function apt-refresh {
    # Refresh debian install and minimum extra packages
    echo "======= apt refresh ==========="
    apt-get update -q
    apt-get upgrade -qy
}


function install-docker {
    echo "======= install docker ==========="
    apt-get install -qy docker.io
}


function install-kubernetes {
    echo "======= install kubernetes =========="
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -qy kubelet kubeadm kubernetes-cni

}

function start-master {
    echo "======= start master ========"
    # kubernetes > 1.7 doesn't like swap + it doesnt make sense anyway See https://github.com/kubernetes/kubernetes/issues/53533
    #  ( TODO: set this properly)
    swapoff -a
    kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address $MASTER_IP --kubernetes-version stable-1.10 --token d7691e.f8ed3c10ca47cb36

}

function settup-nonpriv {
    echo "======= settup non-prived user ======="
    mkdir -p /home/$USERNAME/.kube
    cp -i /etc/kubernetes/admin.conf  /home/$USERNAME/.kube/config
    chown -R $USERNAME:$USERNAME  /home/$USERNAME/.kube
}

function settup-flannel {
    echo "======= settup flannel  ======="

#    su -lc "kubectl create -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml" $USERNAME
    su -lc "kubectl create -f /vagrant/kube-flannel.yml" $USERNAME
    #su -lc "kubectl create -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/k8s-manifests/kube-flannel-rbac.yml" $USERNAME
}

function settup-dashboard {
    echo "======= settup dashboard  ======="
    su -lc "kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/influxdb.yaml" $USERNAME
    su -lc "kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/grafana.yaml" $USERNAME
    su -lc "kubectl create -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/heapster.yaml" $USERNAME
    su -lc "kubectl create -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/kubernetes-dashboard/v1.6.3.yaml" $USERNAME
    su -lc "kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml" $USERNAME

    # "special" LB proxy service so we can see it externally on http://masterip:30888
    su -lc "kubectl create -f /vagrant/kuberdashboard3.yaml" $USERNAME


}







#-----MAIN---------------------------------------------------------


if [ $TESTMODE ]
then
    echo "Test mode functions defined only."
else
    if [ $POSTMODE ]
    then
        echo "postmode"
        postmode
    else
        echo "mainrun"
        main
    fi
fi
