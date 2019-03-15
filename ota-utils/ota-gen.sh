#!/bin/bash

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


new_client() {
  export DEVICE_UUID=${DEVICE_UUID:-$(uuidgen | tr "[:upper:]" "[:lower:]")}
  local device_id=${DEVICE_ID:-${DEVICE_UUID}}
  local device_dir="${DEVICES_DIR}/${DEVICE_UUID}"
  local api="${KUBE_API_URL}/${NAMESPACE}/services"
  local device_registry="${api}/device-registry/proxy"
  
  # Append 8 characters to device_id to make it unique
  device_id=${device_id}-"$(uuidgen | tr "[:upper:]" "[:lower:]" | fold -w 8 | head -n 1)"
  
  mkdir -p "${device_dir}"
  echo ""
  echo "=== New Device Creation ==="
  echo "UUID for device = ${DEVICE_UUID}"
  echo "device_id = ${device_id}"

  # This is a tag for including a chunk of code in the docs. Don't remove. tag::genclientkeys[]
  openssl ecparam -genkey -name prime256v1 | openssl ec -out "${device_dir}/pkey.ec.pem"
  openssl pkcs8 -topk8 -nocrypt -in "${device_dir}/pkey.ec.pem" -out "${device_dir}/pkey.pem"
  openssl req -new -config "${CWD}/certs/client.cnf" -key "${device_dir}/pkey.pem" -out "${device_dir}/${device_id}.csr"
  openssl x509 -req -days 365 -extfile "${CWD}/certs/client.ext" -in "${device_dir}/${device_id}.csr" \
    -CAkey "${DEVICES_DIR}/ca.key" -CA "${DEVICES_DIR}/ca.crt" -CAcreateserial -out "${device_dir}/client.pem"
  cat "${device_dir}/client.pem" "${DEVICES_DIR}/ca.crt" > "${device_dir}/${device_id}.chain.pem"
  ln -s "${SERVER_DIR}/server_ca.pem" "${device_dir}/ca.pem" || true
  openssl x509 -in "${device_dir}/client.pem" -text -noout
  # end::genclientkeys[]

  echo "KUBE_AUTH: ${KUBE_AUTH}"
  RESP_UUID=$(http --ignore-stdin --verify=no PUT "${device_registry}/api/v1/devices" credentials=@"${device_dir}/client.pem" \
    deviceUuid="${DEVICE_UUID}" deviceId="${device_id}" deviceName="${device_id}" deviceType=Other "${KUBE_AUTH}")

  echo "The Device Registry responded with a UUID OF: ${RESP_UUID}"
  [[ ${SKIP_CLIENT} == true ]] && return 0

  echo "ERROR TODO: Get rid of kubectl call here for new_client"
  exit -1
  local gateway=${GATEWAY_ADDR:-$(${KUBECTL} get nodes --output jsonpath \
    --template='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')}
  local addr=${DEVICE_ADDR:-localhost}
  local port=${DEVICE_PORT:-2222}
  local options="-o StrictHostKeyChecking=no"

  ssh ${options} "root@${addr}" -p "${port}" "echo \"${gateway} ota.ce\" >> /etc/hosts"
  scp -P "${port}" ${options} "${device_dir}/client.pem" "root@${addr}:/var/sota/client.pem"
  scp -P "${port}" ${options} "${device_dir}/pkey.pem" "root@${addr}:/var/sota/pkey.pem"
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
  "ca.crt": "$(cat ${SERVER_DIR}/devices/ca.crt | base64 -w 0)"
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
  "new_client")
    new_client
    ;;
  *)
    echo "Unknown command: ${command}"
    exit 1
    ;;
esac
