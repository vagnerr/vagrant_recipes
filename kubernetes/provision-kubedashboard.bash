#!/bin/bash

# Spinup Kubernetes Dashboard on working cluster
#   https://github.com/kubernetes/dashboard
# For implementation resources see
#   https://blog.alexellis.io/kubernetes-in-10-minutes/
#   https://github.com/kubernetes/dashboard/wiki/Accessing-Dashboard---1.7.X-and-above
#   https://github.com/kubernetes/dashboard/wiki/Creating-sample-user

# Start dashboard
#  (https://git.io/kube-dashboard shortlink is no longer valid so using new direct link )
#  (few alternates to this simple dumb install at https://github.com/kubernetes/dashboard/wiki/Installation#recommended-setup)
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml


# Settup token access..
kubectl create -f /vagrant/serviceaccount.xml
kubectl create -f /vagrant/clusterrolebind.xml

# present access token ( to be used for login to web form)
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')

echo "You should now run 'kubectl proxy'"
echo "and assuming portforwardning is in place open browser to..."
echo "http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/"
