#!/bin/sh -e

if [ $# -ne 1 ] ; then
	echo "Usage: $0 <DNS_NAME>"
	echo "  example: $0 example.com"
	exit 1
fi

# Ensure we are in the right place
generated="$(dirname $(readlink -f $0))../generated"
server_dir="$generated/ota-ce.$1"

if [ ! -d "$server_dir" ] ; then
	echo "Path does not exist: $server_dir"
	exit 1
fi

cd $generated
echo "Grabbing garage-sign tool"
curl https://ats-tuf-cli-releases.s3-eu-central-1.amazonaws.com/cli-0.4.0-46-g0298f0a.tgz | tar -xz

cd $server_dir

echo "= Extracting credentials"
../garage-sign/bin/garage-sign init \
    --repo ./tufrepo --credentials ./credentials.zip
echo "= Pulling TUF targets"
../garage-sign/bin/garage-sign targets pull \
    --repo ./tufrepo
echo "= Generating root key"
../garage-sign/bin/garage-sign key generate \
    --repo ./tufrepo --name offline-root --type rsa
echo "= Generating targets key"
../garage-sign/bin/garage-sign key generate \
    --repo ./tufrepo --name offline-targets --type rsa
echo "= Generating rotating keys"
../garage-sign/bin/garage-sign move-offline \
    --repo ./tufrepo --old-root-alias root --new-root offline-root --new-targets offline-targets
echo "= Signing targets with new key"
../garage-sign/bin/garage-sign targets sign \
    --repo ./tufrepo --key-name offline-targets
echo "= Uploading new targets"
../garage-sign/bin/garage-sign targets push \
    --repo ./tufrepo

echo "= Updating credentials.zip with new key"
../garage-sign/bin/garage-sign export-credentials \
    --repo ./tufrepo --target-key-name offline-targets --to credentials.zip
