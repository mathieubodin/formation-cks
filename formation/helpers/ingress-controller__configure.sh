#!/bin/env bash

l_helpers_root=$( dirname -- "${BASH_SOURCE[0]}" | xargs readlink -f)

bash $l_helpers_root/kubernetes_controlplane__install.sh

bash $l_helpers_root/helm__install.sh

bash $l_helpers_root/ingress-controller__install.sh

l_pki_root=$( dirname -- "${BASH_SOURCE[0]}" | xargs readlink -f | xargs dirname )/pki

if [[ ! -f "$l_pki_root/certs/local-ingress.cert.pem" ]] || [[ ! -f "$l_pki_root/private/local-ingress.key.pem" ]]; then
    bash $l_helpers_root/pki__initialize.sh
fi

kubectl create secret tls local-ingress-certs \
    --cert=$l_pki_root/certs/local-ingress.cert.pem \
    --key=$l_pki_root/private/local-ingress.key.pem
