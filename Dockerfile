FROM ubuntu:18.04

RUN apt-get -y update && apt-get -y install unzip openssl curl jq vim httpie zip nodejs npm uuid-runtime

WORKDIR /workspace

COPY ota-utils ./ota-utils

WORKDIR /workspace/ota-utils


