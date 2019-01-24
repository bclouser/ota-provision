FROM ubuntu:18.04

RUN apt-get -y update && apt-get -y install unzip openssl curl jq vim httpie zip nodejs uuid-runtime

WORKDIR /workspace

ADD http://gitlab.toradex.int/infrastructure/kubernetes/-/archive/ota-dev/kubernetes-ota-dev.zip /workspace/

RUN unzip kubernetes-ota-dev.zip

WORKDIR /workspace/kubernetes-ota-dev/ota-community-edition/scripts













