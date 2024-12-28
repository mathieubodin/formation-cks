#! /bin/env bash

# Initialize the PKI
l_pki_root=$( dirname -- "${BASH_SOURCE[0]}" | xargs readlink -f | xargs dirname )/pki

l_pki_certs=${l_pki_root}/certs
l_pki_crl=${l_pki_root}/crl
l_pki_csr=${l_pki_root}/csr
l_pki_newcerts=${l_pki_root}/newcerts
l_pki_private=${l_pki_root}/private

rm -f $l_pki_private/ca.key.pem \
      $l_pki_certs/ca.cert.pem \
      $l_pki_private/local-ingress.key.pem \
      $l_pki_csr/local-ingress.csr.pem \
      $l_pki_certs/local-ingress.cert.pem


openssl genrsa -out $l_pki_private/ca.key.pem 4096
chmod 400 $l_pki_private/ca.key.pem

openssl req -new -x509 -days 365 -sha256 -extensions v3_ca \
            -config $l_pki_root/openssl.cnf \
            -key $l_pki_private/ca.key.pem \
            -out $l_pki_certs/ca.cert.pem

[[ ! -f $l_pki_root/index.txt ]] && touch $l_pki_root/index.txt
[[ ! -f $l_pki_root/serial ]] && echo 1000 > $l_pki_root/serial

# # Generate the local ingress certificate
openssl genrsa -out $l_pki_private/local-ingress.key.pem 4096
chmod 400 $l_pki_private/local-ingress.key.pem
openssl req -new -sha256 --config $l_pki_root/127.0.0.1.nip.io.cnf \
            -key $l_pki_private/local-ingress.key.pem \
            -out $l_pki_csr/local-ingress.csr.pem

openssl ca -batch -extensions server_cert -days 30 -notext -md sha256 \
           -config $l_pki_root/127.0.0.1.nip.io.cnf \
           -in $l_pki_csr/local-ingress.csr.pem \
           -out $l_pki_certs/local-ingress.cert.pem


