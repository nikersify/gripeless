#!/bin/bash
set -euxo pipefail

cd "$(dirname "$0")"

mkcert -install
mkcert supers.localhost "*.supers.localhost"
