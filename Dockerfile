FROM golang:1.12.5 as go-builder
# WORKDIR /go/src/gitlab.toradex.int/ben.clouser/otaprov
RUN go get -insecure gitlab.toradex.int/ben.clouser/otaprov
RUN go install gitlab.toradex.int/ben.clouser/otaprov

# FROM alpine:latest  
# RUN apk --no-cache add ca-certificates
# WORKDIR /root/

# TODO: Convert this to alpine... no reason at all to use ubuntu for this.
FROM ubuntu:18.04

COPY --from=go-builder /go/bin/otaprov /usr/local/bin

RUN apt-get -y update && apt-get -y install unzip openssl curl jq httpie zip uuid-runtime

WORKDIR /workspace/data

COPY certs /workspace/data/certs/
COPY create-device.sh /usr/local/bin/create-device.sh
COPY ota-init.sh /usr/local/bin/ota-init.sh

ENV DATA_PATH=/workspace/data

EXPOSE 8000

