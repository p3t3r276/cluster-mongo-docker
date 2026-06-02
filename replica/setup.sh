#!/usr/bin/env bash
set -euo pipefail

if [ ! -f ./mongo-keyfile ]; then
    docker run --rm -v "$(pwd):/output" mongo:7.0 \
        bash -c "openssl rand -base64 756 > /output/mongo-keyfile && chmod 400 /output/mongo-keyfile"
fi
docker compose up -d
