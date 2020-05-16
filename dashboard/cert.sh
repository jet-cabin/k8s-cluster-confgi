#!/bin/bash

opensslgenrsa-outdashboard.key2048
opensslreq-new-outdashboard.csr-keydashboard.key-subj'/CN=a.jet.com'
opensslx509-req-indashboard.csr-signkeydashboard.key-outdashboard.crt
opensslx509-indashboard.crt-text-noout

#openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./tls.key -out ./tls.crt -subj "/CN=a.jet.com"
#kubectl -n kubernetes-dashboard create secret tls k8s-dashboard-secret --key ./tls.key --cert ./tls.crt
