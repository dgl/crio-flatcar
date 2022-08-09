#!/bin/bash
set -euo pipefail

CRIO_VERSION_TAG="v1.22.5"
CONMON_VERSION_TAG="v2.1.3"
RUNC_VERSION_TAG="v1.1.3"

CHECKOUT_DIR=$(pwd)

# Everything happens within scripts/
pushd scripts

# Drop needed build inputs into sdk_container
pushd sdk_container

# Add app-crypt/gpgme to portage
pushd src/third_party/portage-stable
  if [ ! -d "app-crypt/gpgme" ]; then
    git apply ${CHECKOUT_DIR}/0001-Add-app-crypt-gpgme.patch
  fi
popd

if [ ! -d cri-o ]; then
  git clone https://github.com/cri-o/cri-o
fi
pushd cri-o
git fetch origin
git checkout ${CRIO_VERSION_TAG}
popd

if [ ! -d conmon ]; then
  git clone https://github.com/containers/conmon
fi
pushd conmon
git fetch origin
git checkout ${CONMON_VERSION_TAG}
popd

if [ ! -d runc ]; then
  git clone https://github.com/opencontainers/runc
fi
pushd runc
git fetch origin
git checkout ${RUNC_VERSION_TAG}
popd

popd

# Got inputs, do the builds

./run_sdk_container sudo emerge app-crypt/gpgme

# crio
./run_sdk_container bash -c "cd sdk_container/cri-o && mkdir -p rootfs && make install PREFIX=rootfs/opt/crio DESTDIR=rootfs"

# conmon
./run_sdk_container bash -c "cd sdk_container/conmon && make crio PREFIX=../cri-o/rootfs/opt/crio"

# runc
./run_sdk_container bash -c "cd sdk_container/runc && make"

# Make symlinks in /opt/bin so things end up on the PATH easily
./run_sdk_container bash -c 'cd sdk_container/cri-o/rootfs && mkdir -p opt/bin && cd opt/bin && (for bin in crio crio-status pinns; do ln -s ../crio/bin/\$bin; done)'
./run_sdk_container bash -c 'cd sdk_container/cri-o/rootfs/opt/bin && ln -s ../crio/libexec/crio/conmon'
./run_sdk_container bash -c 'cd sdk_container/cri-o/rootfs/opt/bin && cp ../../../../runc/runc .'

# We now have sdk_container/cri-o/rootfs, package that for flatcar as a tarball, so we can drop it on the root
# (Note: later flatcar recommends systemd sysext, but we use the simple
# approach per
# https://flatcar-linux.org/docs/latest/container-runtimes/use-a-custom-docker-or-containerd-version/
# for now to support older flatcar.)

CRIO_ROOTFS="sdk_container/cri-o/rootfs"

tar -C "${CRIO_ROOTFS}" -cvzf ../crio-rootfs.tgz .
