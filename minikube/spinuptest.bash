#!/bin/bash

kubectl run my-nginx --image=nginx --replicas=2 --port=80

kubectl get deployments

kubectl get pods

kubectl expose deployment my-nginx --type="LoadBalancer"

kubectl get services

