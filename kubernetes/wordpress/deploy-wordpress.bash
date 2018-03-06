#!/bin/bash


echo "persistent volumes-----"
kubectl create -f /vagrant/wordpress/persistent-volume.yaml

echo "secrets--------"
kubectl create secret generic mysql-pass --from-literal=password=SHHTELLNOONE

echo "mysql ------"
kubectl create -f /vagrant/wordpress/mysql-deployment.yaml


echo "wordpress ------"
kubectl create -f /vagrant/wordpress/wordpress-deployment.yaml