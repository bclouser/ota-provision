#!/usr/bin/env bash

docker build --network=host . --tag bclouser/ota-provision && docker push bclouser/ota-provision:latest
