#!/bin/bash

# TODO: Script should become a golang executable
# TODO: Environment should come in from kubernetes configmap

set -euo pipefail

readonly KUBECTL=${KUBECTL:-kubectl}
readonly CWD=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly DNS_NAME=${DNS_NAME:-ota.local}
export   SERVER_NAME=${SERVER_NAME:-ota.ce}
readonly SERVER_DIR=${SERVER_DIR:-${CWD}/../generated/${SERVER_NAME}}
readonly DEVICES_DIR=${DEVICES_DIR:-${SERVER_DIR}/devices}
readonly NAMESPACE=${NAMESPACE:-default}
readonly KUBE_API_TOKEN_FILE=/var/run/secrets/kubernetes.io/serviceaccount/token
readonly namespace_string="x-ats-namespace:${NAMESPACE}"

KUBE_API_TOKEN=$(<${KUBE_API_TOKEN_FILE})
# KUBERNETES_SERVICE_HOST and KUBERNETES_PORT_443_TCP_PORT are defined in all k8 pods
KUBE_API_URL=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/namespaces

KUBE_AUTH=Authorization:"Bearer ${KUBE_API_TOKEN}"
echo "KUBE_API_URL=${KUBE_API_URL}"
echo "KUBE_AUTH=${KUBE_AUTH}"

setup_credentials() {
  local api="${KUBE_API_URL}/${NAMESPACE}/services"
  local keyserver="${api}/tuf-keyserver/proxy"
  local reposerver="${api}/tuf-reposerver/proxy"
  local director="${api}/director/proxy"
  local id
  local keys

  http --ignore-stdin --check-status --verify=no GET ${KUBE_API_URL}/default/secrets/user-keys \
  "${namespace_string}" "${KUBE_AUTH}" &> /dev/null && {
    echo ""
    echo "=== User Keys already exist. Skipping creation of user keys"
    return 0
  }
  echo ""
  echo " === Creating user keys"
  
  # Create entry for specified namespace
  id=$(http --ignore-stdin --verify=no --check-status --print=b POST "${reposerver}/api/v1/user_repo" "${namespace_string}" "${KUBE_AUTH}"  | jq --raw-output .)
  echo "Got id = $id"
  http --ignore-stdin --check-status --verify="no" POST "${director}/api/v1/admin/repo" "${namespace_string}" "${KUBE_AUTH}"
  
  # TODO: Investigate why this isn't instantly available? Is it because it takes time to generate keys? Or is the pod just not ready?
  # Also, *** WEIRD *** we have to send a get request to this URL before we can GET the keys: "<id>/keys/targets/pairs"
  # otherwise a 404 is returned
  i=0
  while ! http --ignore-stdin --check-status --verify="no" GET "${keyserver}/api/v1/root/${id}" "${KUBE_AUTH}"
  do
    echo "Waiting for keys"
    i=$((i+1))
    if [ $i -gt 10 ];then
      echo "Failed to get keys"
      exit -1
    fi
    sleep 2
  done
  keys=$(http --ignore-stdin --check-status --verify="no" GET "${keyserver}/api/v1/root/${id}/keys/targets/pairs" "${KUBE_AUTH}")
  echo "Ok, got keys:"
  echo $keys
  cat > user-keys.json << EOF
  {
  "kind": "Secret",
  "apiVersion": "v1",
  "metadata":{
  "name": "user-keys",
  "namespace": "default"
  },
  "type": "Opaque",
  "data": {
  "id": "$(echo -n ${id} | base64 -w 0)",
  "keys": "$( echo -n ${keys} | base64 -w 0)"
  }
  }
EOF
  echo "==== Creating user-keys secret"
  http --ignore-stdin --check-status --verify=no POST ${KUBE_API_URL}/default/secrets "${KUBE_AUTH}" \
  @user-keys.json | jq '.status' 
}

new_server() {
  http --ignore-stdin --check-status --verify=no GET ${KUBE_API_URL}/default/secrets/gateway-tls \
  "${namespace_string}" "${KUBE_AUTH}" &> /dev/null && {
    echo ""
    echo "=== gateway-tls secret already exists. Skipping creation"
    return 0
  }

  echo ""
  echo "=== Generating Server Keys and Certificates"
  mkdir -p "${SERVER_DIR}" "${DEVICES_DIR}"

  # This is a tag for including a chunk of code in the docs. Don't remove. tag::genserverkeys[]
  openssl ecparam -genkey -name prime256v1 | openssl ec -out "${SERVER_DIR}/ca.key"
  openssl req -new -x509 -days 3650 -config "${CWD}/certs/server_ca.cnf" -key "${SERVER_DIR}/ca.key" \
    -out "${SERVER_DIR}/server_ca.pem"

  openssl ecparam -genkey -name prime256v1 | openssl ec -out "${SERVER_DIR}/server.key"
  openssl req -new -config "${CWD}/certs/server.cnf" -key "${SERVER_DIR}/server.key" -out "${SERVER_DIR}/server.csr"
  openssl x509 -req -days 3650 -extfile "${CWD}/certs/server.ext" -in "${SERVER_DIR}/server.csr" -CAcreateserial \
    -CAkey "${SERVER_DIR}/ca.key" -CA "${SERVER_DIR}/server_ca.pem" -out "${SERVER_DIR}/server.crt"
  cat "${SERVER_DIR}/server.crt" "${SERVER_DIR}/server_ca.pem" > "${SERVER_DIR}/server.chain.pem"

  openssl ecparam -genkey -name prime256v1 | openssl ec -out "${DEVICES_DIR}/ca.key"
  openssl req -new -x509 -days 3650 -key "${DEVICES_DIR}/ca.key" -config "${CWD}/certs/device_ca.cnf" \
    -out "${DEVICES_DIR}/ca.crt"
  # end::genserverkeys[]

  cat > gateway-tls-secret.json << EOF
  {
  "kind": "Secret",
  "apiVersion": "v1",
  "metadata":{
  "name": "gateway-tls",
  "namespace": "default"
  },
  "type": "Opaque",
  "data": {
  "server.key": "$(cat ${SERVER_DIR}/server.key | base64 -w 0)",
  "server.chain.pem": "$(cat ${SERVER_DIR}/server.chain.pem | base64 -w 0)",
  "ca.key": "$(cat ${DEVICES_DIR}/ca.key | base64 -w 0)",
  "ca.crt": "$(cat ${DEVICES_DIR}/ca.crt | base64 -w 0)",
  "server_ca.pem": "$(cat ${SERVER_DIR}/server_ca.pem | base64 -w 0)"
  }
  }
EOF

  echo "==== Creating gateway-tls secret"
  http --ignore-stdin --check-status --verify=no POST ${KUBE_API_URL}/default/secrets "${KUBE_AUTH}" \
  @gateway-tls-secret.json | jq '.'


  echo "==== Creating tuf-keyserver-encryption secret"
  http --ignore-stdin --check-status --verify=no GET ${KUBE_API_URL}/default/secrets/tuf-keyserver-encryption \
    "${namespace_string}" "${KUBE_AUTH}" &> /dev/null && {
      echo ""
      echo "=== tuf-keyserver-encryption secret already exists. Skipping creation"
      return 0
    }

  local salt=$(openssl rand -base64 8)
  local key=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w64 | head -n1)

  cat > tuf-keyserver-encryption.json << EOF
  {
  "kind": "Secret",
  "apiVersion": "v1",
  "metadata":{
  "name": "tuf-keyserver-encryption",
  "namespace": "default"
  },
  "type": "Opaque",
  "data": {
  "DB_ENCRYPTION_SALT": "$(echo -n "${salt}" | base64 -w 0)",
  "DB_ENCRYPTION_PASSWORD": "$(echo -n"${key}" | base64 -w 0)"
  }
  }
EOF
  http --ignore-stdin --check-status --verify=no POST ${KUBE_API_URL}/default/secrets "${KUBE_AUTH}" \
  @tuf-keyserver-encryption.json | jq '.status'
}

[ $# -lt 1 ] && { echo "Usage: $0 <command> [<args>]"; exit 1; }
command=$(echo "${1}" | sed 's/-/_/g')

case "${command}" in
  "new_server")
    new_server
    ;;
  "setup_credentials")
    setup_credentials
    ;;
  *)
    echo "Unknown command: ${command}"
    exit 1
    ;;
esac
