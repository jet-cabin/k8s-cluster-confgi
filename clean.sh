#!/bin/bash

for f in $(ls *.yaml);do
   if [[ $f != "calico.yaml" && $f != "rbac.yaml" && $f != "admin-user.yaml" ]];then
     echo $f
     kubectl delete -f $f
   fi
done
 

kubectl get pod,svc,ing,deployments -A -o wide 
