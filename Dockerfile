FROM ubuntu:18.04

RUN apt-get -y update && apt-get -y install unzip openssl curl jq vim httpie zip nodejs npm uuid-runtime

WORKDIR /workspace

COPY kubernetes ./kubernetes/
COPY api_app ./api_app/

WORKDIR /workspace/api_app

RUN npm install

EXPOSE 3000
ENV DEBUG="api-app"
ENTRYPOINT [ "npm", "start" ]




