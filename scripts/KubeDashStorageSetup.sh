#!/bin/sh
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
kubectl apply -f ../deployement/k8s-dashboard-access.yml
git clone https://github.com/rancher/local-path-provisioner.git
cd local-path-provisioner
helm install local-path-storage --create-namespace --namespace local-path-storage ./deploy/chart/local-path-provisioner/