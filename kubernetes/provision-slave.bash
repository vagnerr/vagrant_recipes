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
    echo "======= PROVISIONING (Slave) =========="
    #getenvs
    apt-refresh
    install-docker
    install-kubernetes
    start-slave


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

function start-slave {
                        # HARDCODED COPY TODO: fix with master properly
    kubeadm join --token  d7691e.f8ed3c10ca47cb36 $MASTER_IP:6443
}




#-----MAIN---------------------------------------------------------


if [ $TESTMODE ]
then
    echo "Test mode functions defined only."
else
    main
fi