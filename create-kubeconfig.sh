#!/bin/bash

PROJECT="k8-the-hard-way"
PUBLIC_IP="$PROJECT-lb-ip"
CLUSTER="$PROJECT-cluster"

if [ ! -d ./ssl ]; then
    echo "ssl certificates do not exists"
    echo "execute create-certificate.sh before"
    exit 0
fi

pushd ./ssl/

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe $PUBLIC_IP \
    --region $(gcloud config get-value compute/region) \
    --format 'value(address)')


# kubeconfig for worker nodes
for i in 0 1; do
    instance="worker-${i}"

    kubectl config set-cluster $CLUSTER \
        --certificate-authority=ca.pem \
        --embed-certs=true \
        --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
        --kubeconfig=${instance}.kubeconfig

    kubectl config set-credentials system:node:${instance} \
        --client-certificate=${instance}.pem \
        --client-key=${instance}-key.pem \
        --embed-certs=true \
        --kubeconfig=${instance}.kubeconfig

    kubectl config set-context default \
        --cluster=$CLUSTER \
        --user=system:node:${instance} \
        --kubeconfig=${instance}.kubeconfig

    kubectl config use-context default --kubeconfig=${instance}.kubeconfig

done


# kubeconfig for kube proxy 
kubectl config set-cluster $CLUSTER \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
    --cluster=$CLUSTER \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig


# kubeconfig for kube-controll-manager
kubectl config set-cluster $CLUSTER \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
    --cluster=$CLUSTER \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig


# kubeconfig for kube-scheduler
kubectl config set-cluster $CLUSTER \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
    --cluster=$CLUSTER \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig


# kubeconfig for admin user
kubectl config set-cluster $CLUSTER \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

kubectl config set-context default \
    --cluster=$CLUSTER \
    --user=admin \
    --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig


for i in 0 1; do

    worker="worker-${i}"
    gcloud compute scp ${worker}.kubeconfig kube-proxy.kubeconfig ${worker}:~/    

    controller="controller-${i}"
    gcloud compute scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${controller}:~/

done

popd