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
    apt-dependencies
    kuber1-hyperkube
    kuber2-docker
    kuber3-etcd
    kuber4-flanneld
    kuber5-reconfigdocker
    kuber6-apiserver
    kuber7-controller
    kuber8-kublet
    kuber9-proxy
    kuber10-scheduler
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

function apt-dependencies {
    apt-get install -y            \
        apt-transport-https         \
        ca-certificates             \
        curl                        \
        software-properties-common
}

function kuber1-hyperkube {
    # Add kubernetes
    echo "======= Kubernetes =========="
    # Based on GutHubGist from @apokalyptik
    # see https://gist.github.com/apokalyptik/99cefb3d2e16b9b0c3141e222f3267db

    echo "--- Step 1: Get Ready ---"
    # Note: Not as clean as it *could* be current release ( 1.6.7 )is  a small 5 meg
    #       tar with an install command to get the binaries ( which pulls the sub-package )
    #       for now following @apokalyptik process but pulling the second layer which was
    #       listed in the change log announcement
    #        (https://groups.google.com/forum/#!topic/kubernetes-announce/LnJD3DBAJig)
    #TODO: try pulling the official latest release and run the "installer" in it
    curl \
        --silent    \
        --location  \
        https://dl.k8s.io/v1.6.7/kubernetes-server-linux-amd64.tar.gz \
            | tar --to-stdout -zxf - kubernetes/server/bin/hyperkube > /usr/bin/hyperkube
    chmod a+x /usr/bin/hyperkube
    cd /usr/bin/
    /usr/bin/hyperkube --make-symlinks
    mkdir -p /var/lib/k8s
    groupadd kube
    useradd kube -g kube -d /var/lib/k8s/ -s /bin/false
    chown kube:kube /var/lib/k8s
}

function kuber2-docker {
    # Using mostly the standard docker-ce install instructions for debian rather
    # than those of @apokalyptik, also adding docker-compose incase I want to
    # drive docker directly with compose files.
    echo "--- Step 2: Install Docker ---"
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
    add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/debian \
        $(lsb_release -cs) \
        stable"
    apt-get update  && \
    apt-get install -y \
        docker-ce        \
        docker-compose
    #curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.20.0/minikube-linux-amd64 && \
    #chmod +x minikube && \
    #mv minikube /usr/local/bin/

    # @erikbgithub commented on Mar 20  (https://gist.github.com/apokalyptik/99cefb3d2e16b9b0c3141e222f3267db)
    echo "--Tweek docker systemd opts--"
    sudo mkdir -p /etc/systemd/system/docker.service.d/
    cp /vagrant/master/etc/systemd/system/docker.service.d/clear_mount_propagtion_flags.conf  \
        /etc/systemd/system/docker.service.d/clear_mount_propagtion_flags.conf
    sudo systemctl daemon-reload
    sudo systemctl restart docker.service

}

function kuber3-etcd {
    echo "--- Step 3: Install ETCD ---"
    # Give it a home
    groupadd etcd
    useradd etcd -d /var/lib/k8s/etcd -s /bin/false -g etcd
    mkdir -p /var/lib/k8s/etcd
    chown etcd:etcd /var/lib/k8s/etcd -R
    # download and install #TODO: get latest build?
    cd /usr/local/src
    curl \
        --silent \
        --location \
        'https://github.com/coreos/etcd/releases/download/v3.0.4/etcd-v3.0.4-linux-amd64.tar.gz' \
        | tar -zvxf-
    cd etcd-v3.0.4-linux-amd64
    cp etcd /usr/bin/
    cp etcdctl /usr/bin/
    # Define it
    # Note: use /etc/systemd, not /lib/systemd, thats for proper package installs IMHO
    cat /vagrant/master/etc/systemd/system/etcd.service \
        | sed -e "s/@@MY_HOST_IP@@/$MY_HOST_IP/" \
        > /etc/systemd/system/etcd.service

    # Start it
    systemctl daemon-reload
    systemctl enable etcd
    systemctl start etcd

}

function kuber4-flanneld {


    echo "--- Step 4: FlannelD ---"
    # Pre-Configure FlannelD via ETCD
    #TODO: Parameterise the network address to use FLANNEL_NETWORK
    etcdctl set /coreos.com/network/config '{ "Network": "192.168.32.0/19" }'
    # Download and install..
    # TODO: Latest version?
#      'https://github.com/coreos/flannel/releases/download/v0.5.5/flannel-0.5.5-linux-amd64.tar.gz' \

    cd /usr/local/src
    curl \
      --silent \
      --location \
      'https://github.com/coreos/flannel/releases/download/v0.8.0/flannel-v0.8.0-linux-amd64.tar.gz' \
        | tar -zvxf-
    #cd flannel-0.8.0
    cp flanneld /usr/bin
    mkdir -p /var/lib/k8s/flannel/networks
    # Define it.
    # Note /etc/systemd not /lib...
    cat /vagrant/master/etc/systemd/system/flanneld.service \
        | sed -e "s/@@MY_HOST_IP@@/$MY_HOST_IP/" \
        > /etc/systemd/system/flanneld.service

    # Start it
    systemctl daemon-reload
    systemctl enable flanneld
    echo "STARTING flanneld"
    systemctl start flanneld

}


function kuber5-reconfigdocker {

    echo "--- Step 5: Reconfigure docker to use FlannelD ---"
    # redefine it
    # note /etc/systemd not /lib
    # TODO: diff dist version and new one and convert to
    #       /etc/systemd/system/docker.service.d/xxxx
    cp /vagrant/master/etc/systemd/system/docker.service  \
        /etc/systemd/system/docker.service

    # give kube access
    gpasswd -a kube docker
    #reload
    systemctl daemon-reload
    systemctl restart docker

}


function kuber6-apiserver {

    echo "--- Step 6: Kubernetes API Server ---"
    # make a home
    mkdir -p /var/lib/k8s/kubernetes/crt
    chown kube:kube /var/lib/k8s/kubernetes/crt /var/lib/k8s/kubernetes

    # define service account
    if [[ ! -f /var/lib/k8s/kubernetes/kube-serviceaccount.key ]]; then
    openssl genrsa -out /var/lib/k8s/kubernetes/kube-serviceaccount.key 2048 2>/dev/null
    fi
    chown kube:kube /var/lib/k8s/kubernetes/kube-serviceaccount.key

    # define it
    cat /vagrant/master/etc/systemd/system/kube-apiserver.service \
        | sed -e "s/@@MY_HOST_IP@@/$MY_HOST_IP/" \
        > /etc/systemd/system/kube-apiserver.service

    # Enable it
    systemctl daemon-reload
    systemctl enable kube-apiserver
    systemctl start kube-apiserver


}

function kuber7-controller {

    echo "--- Step 7: Kubernetes controller-manager ---"
    # define it
    cat /vagrant/master/etc/systemd/system/kube-controller-manager.service \
        | sed -e "s/@@MASTER_IP@@/$MASTER_IP/" \
        > /etc/systemd/system/kube-controller-manager.service


    #Enable it
    systemctl daemon-reload
    systemctl enable kube-controller-manager
    systemctl start kube-controller-manager


}

function kuber8-kublet {

    echo "--- Step 8 Kubernetes Kubelet ---"
    #Define it
    cat /vagrant/master/etc/systemd/system/kube-kubelet.service \
        | sed -e "s/@@MASTER_IP@@/$MASTER_IP/" \
        > /etc/systemd/system/kube-kubelet.service

    #Enable it
    systemctl daemon-reload
    systemctl enable kube-kubelet
    service kube-kubelet start

}


function kuber9-proxy {

    echo "--- Step 9: Kubernetes Proxy ---"
    #Define it
    cat /vagrant/master/etc/systemd/system/kube-proxy.service \
        | sed -e "s/@@MASTER_IP@@/$MASTER_IP/" \
        > /etc/systemd/system/kube-proxy.service

    #Enable it
    systemctl daemon-reload
    systemctl enable kube-proxy
    systemctl start kube-proxy
}

function kuber10-scheduler {

    echo "--- Step 10: Kubernetes Scheduler ---"
    #Define it
    cat /vagrant/master/etc/systemd/system/kube-scheduler.service \
        | sed -e "s/@@MASTER_IP@@/$MASTER_IP/" \
        > /etc/systemd/system/kube-scheduler.service

    #Enable it
    systemctl daemon-reload
    systemctl enable kube-scheduler
    systemctl start kube-scheduler

}

#-----MAIN---------------------------------------------------------


if [ $TESTMODE ]
then
    echo "Test mode functions defined only."
else
    main
fi