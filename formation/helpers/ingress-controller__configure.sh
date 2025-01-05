#!/bin/env bash

bash ./kubernetes_controlplane__install.sh

bash ./helm__install.sh

bash ./ingress-controller__install.sh

l_pki_root=$( dirname -- "${BASH_SOURCE[0]}" | xargs readlink -f | xargs dirname )/pki

if [[ ! -f "$l_pki_root/certs/local-ingress.cert.pem" ]] || [[ ! -f "$l_pki_root/private/local-ingress.key.pem" ]]; then
    bash ./pki__initialize.sh
fi

kubectl create secret tls local-ingress-certs \
    --cert=$l_pki_root/certs/local-ingress.cert.pem \
    --key=$l_pki_root/private/local-ingress.key.pem
