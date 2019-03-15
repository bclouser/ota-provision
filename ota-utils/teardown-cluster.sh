#!/usr/bin/env bash

SCRIPT_DIR="$(dirname $(readlink -f $0))"

## Get the NFS server information before blowing everything away
# All the OTA Persistent Volumes share the same directory. So we can just look at one of them
NFS_SERVER=$(kubectl get pv --selector=app="ota" --output jsonpath='{.items[0].spec.nfs.server}' 2> /dev/null) || NFS_SERVER=""
NFS_PATH=$(kubectl get pv --selector=app="ota" --output jsonpath='{.items[0].spec.nfs.path}' 2> /dev/null) || NFS_PATH=""


## Manually delete the PVC
echo "==== Deleting Persistent Volume Claims..."
pvc=$(kubectl get pvc --selector=app="kafka" --output jsonpath='{.items[0].metadata.name}' 2>  /dev/null) && echo "Deleting kafka pvc" && kubectl delete pvc $pvc &
pvc=$(kubectl get pvc --selector=app="treehub" --output jsonpath='{.items[0].metadata.name}' 2> /dev/null) && echo "Deleting treehub pvc" && kubectl delete pvc $pvc &
pvc=$(kubectl get pvc --selector=app="zookeeper" --output jsonpath='{.items[0].metadata.name}' 2> /dev/null) && echo "Deleting zookeeper pvc" && kubectl delete pvc $pvc &

pvc_mysql_0=$(kubectl get pvc --selector=app="mysql" --output jsonpath='{.items[0].metadata.name}' 2> /dev/null)
pvc_mysql_1=$(kubectl get pvc --selector=app="mysql" --output jsonpath='{.items[1].metadata.name}' 2> /dev/null)
echo "Deleting mysql pvcs" && kubectl delete pvc $pvc_mysql_0 $pvc_mysql_1 &


sleep 2; # Give pvc just a smidge of time to delete... found it to prevent hangs

echo "==== Deleting services..."
kubectl delete -f ${SCRIPT_DIR}/../services.yaml
kubectl delete -f ${SCRIPT_DIR}/../api-gateway.yaml

echo "==== Deleting infra..."
kubectl delete -f ${SCRIPT_DIR}/../generated/infra.yaml.tmpl

echo "==== Deleting secrets..."
kubectl delete secret tuf-keyserver-encryption 
kubectl delete secret user-keys
kubectl delete secret gateway-tls

echo "==== Deleting generated directory..."
rm -rf ${SCRIPT_DIR}/../generated

#echo "=== Deleting artifact files on our local storage"
#for PV_NUM in 0 1 2 3 4
#do
#	pv=$(kubectl get pv --selector=app="ota" --output jsonpath="{.items[${PVC_NUM}].metadata.name}" 2> /dev/null) \
#	 && echo "Deleting pv ${PV_NUM}" && kubectl delete pv $pv
#done




#echo "=== Deleting artifact files on the NFS Mount"
#if [ -z "$NFS_SERVER" ] || [ -z "$NFS_PATH" ]; then
#    echo "Invalid NFS server or path"
#    exit -1;
#fi
#
## We really need some kind of proper timeout here for hosts that don't have access to the .254 subnet
#ping -c 1 ${NFS_SERVER}
#
#if [ ${?} -ne 0 ]; then
#	echo "NFS SERVER Unreachable. Stopping..."
#	exit -1
#fi

#MOUNT_DIR=$(mktemp -d)
#echo "sudo mount ${NFS_SERVER}:${NFS_PATH} ${MOUNT_DIR}"
#sudo mount ${NFS_SERVER}:${NFS_PATH} ${MOUNT_DIR} || {
#    echo "Failed to mount nfs shared drive"
#    exit -1
#}
#
##sudo rm -r ${MOUNT_DIR}/*
#
#sudo umount ${MOUNT_DIR} && sudo rm -r ${MOUNT_DIR}

