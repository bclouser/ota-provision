

  ## To build the credentials.zip:
   * We will need to fetch a few things...

  ### server_ca.pem:
  we can get it from gateway-tls secret (need to add it first)
  
  ### autoprov.url:
  * We can get from ota-provision secret
  echo "https://${SERVER_NAME}:30443" > "${SERVER_DIR}/autoprov.url"

  ### tufrepo.url:
  * We can get from ota-provision secret
  echo "http://api.${DNS_NAME}/repo/" > "${SERVER_DIR}/tufrepo.url"

  ### treehub.json:
  * We can get from ota-provision secret
  cat > "${SERVER_DIR}/treehub.json" <<END
  {
      "oauth2": {
        "server": "http://oauth2.${DNS_NAME}",
             "client_id" : "7a455f3b-2234-43b5-9d13-7d8823494f21",
             "client_secret" : "OTbGcZx6my"
           },
           "ostree": {
               "server": "http://api.${DNS_NAME}/treehub/api/v3/"
           }
         }
END




  ### targets.pub & targets.sec:
  // TODO, add in the get_credentials function in the ota-provision container... but dont create the actual credentials.zip
  // We will then be able to get these from the user-keys secret in kubernetes
  echo ${keys} | jq '.[0] | {keytype, keyval: {public: .keyval.public}}'   > "${SERVER_DIR}/targets.pub"
  echo ${keys} | jq '.[0] | {keytype, keyval: {private: .keyval.private}}' > "${SERVER_DIR}/targets.sec"



  ### root.json:
  http --ignore-stdin --check-status --verify=no -d -o "${SERVER_DIR}/root.json" GET \
   ${reposerver}/api/v1/user_repo/root.json "${namespace_string}" "${KUBE_AUTH}"
