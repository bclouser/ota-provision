#!/usr/bin/env bash

#docker build --no-cache --network=host . --tag bclouser/ota-provision && docker push bclouser/ota-provision:latest
docker build --network=host . --tag bclouser/ota-provision && docker push bclouser/ota-provision:latest
