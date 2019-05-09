# OTA Provision Container

Contains scripts that are used to setup the ota deployment.

Additionally, this container contains a golang application which supports REST endpoints for attaining/creating OTA artifacts such as credentials.zip and device certs.

Golang application: http://gitlab.toradex.int/ben.clouser/otaprov

## Building
*NOTE:* Currently this has to be built inside toradex network because it pulls from internal repo
*NOTE:* The _--network=host_ is necessary to pick up gitlab.toradex.int
``` docker build --network=host .```