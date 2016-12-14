#!/bin/bash

# This script builds the base and release images for use by the release build and image builds.

STARTTIME=$(date +%s)
source "$(dirname "${BASH_SOURCE}")/lib/init.sh"

! docker run --rm --privileged multiarch/qemu-user-static:register;
os::util::ensure::built_binary_exists 'oc'

function build() {
  eval "oc ex dockerbuild $2 $1 ${OS_BUILD_IMAGE_ARGS:-}"
}

# Build the images
#build openshift/origin-base                   "${OS_ROOT}/images/base"
#build openshift/origin-haproxy-router-base    "${OS_ROOT}/images/router/haproxy-base"
#build openshift/origin-release                "${OS_ROOT}/images/release"

# if linux/arm exists then build also the arm images
#if [[ -d "${OS_ROOT}"/_output/local/bin/linux/arm ]]; then
	# enable ability to execute and build arm containers
	! docker run --rm --privileged multiarch/qemu-user-static:register;
	
	# Build the images
	build raffaelespazzoli/origin-base-arm                   "${OS_ROOT}/images/base --dockerfile=${OS_ROOT}/images/base/Dockerfile.armhf";
	build raffaelespazzoli/origin-haproxy-router-base-arm    "${OS_ROOT}/images/router/haproxy-base --dockerfile=${OS_ROOT}/images/router/haproxy-base/Dockerfile.armhf";
	build raffaelespazzoli/origin-release-arm               "${OS_ROOT}/images/release --dockerfile=${OS_ROOT}/images/release/Dockerfile.armhf";
#fi

ret=$?; ENDTIME=$(date +%s); echo "$0 took $(($ENDTIME - $STARTTIME)) seconds"; exit "$ret"
