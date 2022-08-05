#!/bin/bash
set -euo pipefail

: ${FLATCAR_VERSION?Must be set to flatcar branch version (e.g. flatcar-1234)}

set -x

if [ ! -d scripts ]; then
  git clone https://github.com/flatcar-linux/scripts
fi
pushd scripts
./checkout "${FLATCAR_VERSION}"

# Prepares the container, the command doesn't matter, but this gets the minor
# version into the build log.
./run_sdk_container cat /etc/os-release
