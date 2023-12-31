#!/bin/sh
sudo kubeadm config images pull
PRIVATEIP=$(hostname -I | awk '{print $1}')
sudo kubeadm init --pod-network-cidr=10.244.0.0/16  --upload-certs --control-plane-endpoint "${PRIVATEIP}:6443"
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# sudo kubeadm join &lt;MASTER_NODE_IP>:&lt;API_SERVER_PORT> --token &lt;TOKEN> --discovery-token-ca-cert-hash &lt;CERTIFICATE_HASH>
# kubectl get no 
#add workers to /etc/hosts
#scp ~/.kube/config secondk8s1:~/.kube/config