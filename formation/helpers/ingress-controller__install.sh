#!/bin/env bash




helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade \
    --install ingress-nginx ingress-nginx/ingress-nginx \
    --create-namespace \
    --namespace ingress-nginx \
    --set controller.kind=Deployment \
    --set controller.replicaCount=1 \
    --set controller.tolerations[0].key=node-role.kubernetes.io/control-plane \
    --set controller.tolerations[0].operator=Exists \
    --set controller.tolerations[0].effect=NoSchedule \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
    --set controller.service.enabled=true \
    --set controller.service.type=NodePort \
    --set controller.service.nodePorts.http=30080 \
    --set controller.service.nodePorts.https=30443 \
    --set controller.admissionWebhooks.service.enabled=true \
    --set controller.admissionWebhooks.patch.tolerations[0].key=node-role.kubernetes.io/control-plane \
    --set controller.admissionWebhooks.patch.tolerations[0].operator=Exists \
    --set controller.admissionWebhooks.patch.tolerations[0].effect=NoSchedule

echo
echo
echo "Ingress controller installed successfully"
