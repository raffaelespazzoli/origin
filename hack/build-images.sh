#!/bin/bash

# This script builds all images locally except the base and release images,
# which are handled by hack/build-base-images.sh.

# NOTE:  you only need to run this script if your code changes are part of
# any images OpenShift runs internally such as origin-sti-builder, origin-docker-builder,
# origin-deployer, etc.
STARTTIME=$(date +%s)
source "$(dirname "${BASH_SOURCE}")/lib/init.sh"
source "${OS_ROOT}/contrib/node/install-sdn.sh"

if [[ "${OS_RELEASE:-}" == "n" ]]; then
  # Use local binaries
  imagedir="${OS_OUTPUT_BINPATH}/linux/amd64"
 imagedir_arm="${OS_OUTPUT_BINPATH}/linux/arm64"
  # identical to build-cross.sh
  os::build::os_version_vars
  OS_RELEASE_COMMIT="${OS_GIT_VERSION//+/-}"
  OS_BUILD_PLATFORMS=("${OS_IMAGE_COMPILE_PLATFORMS[@]-}")

  echo "Building images from source ${OS_RELEASE_COMMIT}:"
  echo
  OS_GOFLAGS="${OS_GOFLAGS:-} ${OS_IMAGE_COMPILE_GOFLAGS}" os::build::build_static_binaries "${OS_IMAGE_COMPILE_TARGETS[@]-}" "${OS_SCRATCH_IMAGE_COMPILE_TARGETS[@]-}"
	os::build::place_bins "${OS_IMAGE_COMPILE_BINARIES[@]}"
  echo
else
  # Get the latest Linux release
  if [[ ! -d _output/local/releases ]]; then
    echo "No release has been built. Run hack/build-release.sh"
    exit 1
  fi

  # Extract the release archives to a staging area.
  os::build::detect_local_release_tars "linux-64bit"

  echo "Building images from release tars for commit ${OS_RELEASE_COMMIT}:"
  echo " primary: $(basename ${OS_PRIMARY_RELEASE_TAR})"
  echo " image:   $(basename ${OS_IMAGE_RELEASE_TAR})"

  imagedir="${OS_OUTPUT}/images"
  rm -rf ${imagedir}
  mkdir -p ${imagedir}
  os::build::extract_tar "${OS_PRIMARY_RELEASE_TAR}" "${imagedir}"
  os::build::extract_tar "${OS_IMAGE_RELEASE_TAR}" "${imagedir}"
fi

! docker run --rm --privileged multiarch/qemu-user-static:register;

os::util::ensure::built_binary_exists 'oc'

function build() {
eval "oc ex dockerbuild $2 $1 $3 ${OS_BUILD_IMAGE_ARGS:-}"
}

# Create link to file if the FS supports hardlinks, otherwise copy the file
function ln_or_cp {
  local src_file=$1
  local dst_dir=$2
  if os::build::is_hardlink_supported "${dst_dir}" ; then
    ln -f "${src_file}" "${dst_dir}"
  else
    cp -pf "${src_file}" "${dst_dir}"
  fi
}

if [[ -d "${OS_ROOT}"/_output/local/bin/linux/arm ]]; then

cp -Rpf "${OS_ROOT}/images" "images"
cp -Rpf "${OS_ROOT}/examples" "${OS_OUTPUT}/examples_arm"

fi
 
# Link or copy primary binaries to the appropriate locations.
ln_or_cp "${imagedir}/openshift" images/origin/bin

# Link or copy image binaries to the appropriate locations.
ln_or_cp "${imagedir}/pod"             images/pod/bin
ln_or_cp "${imagedir}/hello-openshift" examples/hello-openshift/bin
ln_or_cp "${imagedir}/deployment"      examples/deployment/bin
ln_or_cp "${imagedir}/gitserver"       examples/gitserver/bin
ln_or_cp "${imagedir}/dockerregistry"  images/dockerregistry/bin

if [[ -d "${OS_ROOT}"/_output/local/bin/linux/arm ]]; then
#same for arm
# Link or copy primary binaries to the appropriate locations.
ln_or_cp "${imagedir_arm}/openshift" "images/origin/bin"

# Link or copy image binaries to the appropriate locations.
ln_or_cp "${imagedir_arm}/pod"             "${OS_OUTPUT}/images_arm/pod/bin"
ln_or_cp "${imagedir_arm}/hello-openshift" "${OS_OUTPUT}/examples_arm/hello-openshift/bin"
ln_or_cp "${imagedir_arm}/deployment"      "${OS_OUTPUT}/examples_arm/deployment/bin"
ln_or_cp "${imagedir_arm}/gitserver"       "${OS_OUTPUT}/examples_arm/gitserver/bin"
ln_or_cp "${imagedir_arm}/oc"              "${OS_OUTPUT}/examples_arm/gitserver/bin"
ln_or_cp "${imagedir_arm}/dockerregistry"  "${OS_OUTPUT}/images_arm/dockerregistry/bin"

fi

# Copy SDN scripts into images/node
os::provision::install-sdn "${OS_ROOT}" "${imagedir}" "${OS_ROOT}/images/node"
mkdir -p images/node/conf/
cp -pf "${OS_ROOT}/contrib/systemd/openshift-sdn-ovs.conf" images/node/conf/

#same for arm
if [[ -d "${OS_ROOT}"/_output/local/bin/linux/arm ]]; then
	
	# Copy SDN scripts into images/node
os::provision::install-sdn "${OS_ROOT}" "${OS_OUTPUT}/images_arm/node"
mkdir -p "${OS_OUTPUT}/images_arm/node/conf/"
cp -pf "${OS_ROOT}/contrib/systemd/openshift-sdn-ovs.conf" "${OS_OUTPUT}/images_arm/node/conf/"
	
fi

# builds an image and tags it two ways - with latest, and with the release tag
function image {
  local STARTTIME=$(date +%s)
  echo "--- $1 ---"
  #eval "oc ex dockerbuild $2 $1 ${OS_BUILD_IMAGE_ARGS:-}"
  build $1:latest $2
  #docker build -t $1:latest $2
  docker tag $1:latest $1:${OS_RELEASE_COMMIT}
  git clean -fdx ${2%% *}
  local ENDTIME=$(date +%s); echo "--- $1 took $(($ENDTIME - $STARTTIME)) seconds ---"
  echo
  echo
}

## images that depend on scratch / centos
#image openshift/origin-pod                   images/pod
#image openshift/openvswitch                  images/openvswitch
## images that depend on openshift/origin-base
#image openshift/origin                       images/origin
#image openshift/origin-haproxy-router        images/router/haproxy
#image openshift/origin-keepalived-ipfailover images/ipfailover/keepalived
#image openshift/origin-docker-registry       images/dockerregistry
#image openshift/origin-egress-router         images/router/egress
## images that depend on openshift/origin
#image openshift/origin-gitserver             examples/gitserver
#image openshift/origin-deployer              images/deployer
#image openshift/origin-recycler              images/recycler
#image openshift/origin-docker-builder        images/builder/docker/docker-builder
#image openshift/origin-sti-builder           images/builder/docker/sti-builder
#image openshift/origin-f5-router             images/router/f5
#image openshift/node                         images/node
#
## extra images (not part of infrastructure)
#image openshift/hello-openshift              examples/hello-openshift
#docker build --no-cache -t openshift/deployment-example:v1 examples/deployment
#docker build --no-cache -t openshift/deployment-example:v2 -f examples/deployment/Dockerfile.v2 examples/deployment


#arm
#if [[ -d "${OS_ROOT}"/_output/local/bin/linux/arm ]]; then
! docker run --rm --privileged multiarch/qemu-user-static:register;
# images that depend on scratch / centos
image raffaelespazzoli/origin-pod-arm                   "images/pod --dockerfile=images/pod/Dockerfile.armhf"
image raffaelespazzoli/openvswitch-arm                  "images/openvswitch --dockerfile=images/openvswitch/Dockerfile.armhf"
# images that depend on openshift/origin-base
image raffaelespazzoli/origin-arm                       "images/origin --dockerfile=images/origin/Dockerfile.armhf"
image raffaelespazzoli/origin-haproxy-router-arm        "images/router/haproxy --dockerfile=images/router/haproxy/Dockerfile.armhf"
image raffaelespazzoli/origin-keepalived-ipfailover-arm "images/ipfailover/keepalived --dockerfile=images/ipfailover/keepalived/Dockerfile.armhf"
image raffaelespazzoli/origin-docker-registry-arm       "images/dockerregistry --dockerfile=images/dockerregistry/Dockerfile.armhf"
image raffaelespazzoli/origin-egress-router-arm         "images/router/egress --dockerfile=images/router/egress/Dockerfile.armhf"
#image raffaelespazzoli/origin-gitserver-arm             "examples/gitserver --dockerfile=examples/gitserver/Dockerfile.armhf"
# images that depend on openshift/origin
image raffaelespazzoli/origin-deployer-arm              "images/deployer --dockerfile=images/deployer/Dockerfile.armhf"
image raffaelespazzoli/origin-recycler-arm              "images/recycler --dockerfile=images/recycler/Dockerfile.armhf"
image raffaelespazzoli/origin-docker-builder-arm        "images/builder/docker/docker-builder --dockerfile=images/builder/docker/docker-builder/Dockerfile.armhf"
image raffaelespazzoli/origin-sti-builder-arm           "images/builder/docker/sti-builder --dockerfile=images/builder/docker/sti-builder/Dockerfile.armhf"
image raffaelespazzoli/origin-f5-router-arm             "images/router/f5 --dockerfile=images/router/f5/Dockerfile.armhf"
image raffaelespazzoli/node-arm                         "images/node --dockerfile=images/node/Dockerfile.armhf"

# extra images (not part of infrastructure)
#image raffaelespazzoli/hello-openshift-arm              "examples/hello-openshift --dockerfile=examples/hello-openshift/Dockerfile.armhf"
#docker build --no-cache -t raffaelespazzoli/deployment-example-arm:v1 -f "examples/deployment/Dockerfile.armhf" "example/deployment"
#docker build --no-cache -t raffaelespazzoli/deployment-example-arm:v2 -f "examples/deployment/Dockerfile.v2.armhf" "examples/deployment"
#fi


echo
echo
echo "++ Active images"

docker images | grep openshift/ | grep ${OS_RELEASE_COMMIT} | sort
echo

ret=$?; ENDTIME=$(date +%s); echo "$0 took $(($ENDTIME - $STARTTIME)) seconds"; exit "$ret"
