#!/bin/bash
set -e

args=("$@")
if [ $# -ne 3 ]
then
  echo "Usage: `basename $0` build_ref distro_release distro_component"
  echo "eg. `basename $0` 4deb3ef precise experimental"
  exit 2
fi

DATE=$(date +%Y%m%d%H%M%S)
FLAPJACK_BUILD_REF=$1
DISTRO_RELEASE=$2
DISTRO_COMPONENT=$3
VALID_COMPONENTS=(main experimental)

FLAPJACK_FULL_VERSION=$(wget -qO - https://raw.githubusercontent.com/flapjack/flapjack/${FLAPJACK_BUILD_REF}/lib/flapjack/version.rb | grep 'VERSION' | cut -d '"' -f 2)
: ${FLAPJACK_FULL_VERSION:?"Incorrect build_ref.  Tags should be specified as 'v1.0.0rc3'" }
FLAPJACK_MAJOR_VERSION=$(echo $FLAPJACK_FULL_VERSION |  cut -d . -f 1,2)

sudo docker run -i -t -e "FLAPJACK_BUILD_REF=${FLAPJACK_BUILD_REF}" \
-e "FLAPJACK_PACKAGE_VERSION=${FLAPJACK_FULL_VERSION}~${DATE}-${FLAPJACK_BUILD_REF}" \
flapjack/omnibus-ubuntu bash -c \
"cd omnibus-flapjack ; \
git pull ; \
bundle install --binstubs ; \
bin/omnibus build --log-level=info flapjack"

container_id=`sudo docker ps -l -q`
sudo docker cp ${container_id}:/omnibus-flapjack/pkg .
sudo docker rm ${container_id}

# Check if awscli exists
if ! hash aws 2>/dev/null; then
  sudo apt-get install -y awscli
fi

# Check if aptly exists
if ! hash aptly 2>/dev/null; then
  if [ -f /etc/debian_version ]; then
    echo 'deb http://repo.aptly.info/ squeeze main' | sudo tee  /etc/apt/sources.list.d/aptly.list
    gpg --keyserver keys.gnupg.net --recv-keys 2A194991
    gpg -a --export 2A194991 | sudo apt-key add -

    sudo apt-get update
    if !sudo apt-get install -y aptly ; then
      echo "Error installing aptly." ; exit $? ;
    fi

    # Create aptly config file
    cat << EOF > aptly.conf
{
  "rootDir": "${PWD}/aptly",
  "downloadConcurrency": 4,
  "downloadSpeedLimit": 0,
  "architectures": [],
  "dependencyFollowSuggests": false,
  "dependencyFollowRecommends": false,
  "dependencyFollowAllVariants": false,
  "dependencyFollowSource": false,
  "gpgDisableSign": false,
  "gpgDisableVerify": false,
  "downloadSourcePackages": false,
  "S3PublishEndpoints": {}
}
EOF
  fi
fi
# End aptly installation

# Put packages into aptly repo, sync with S3
mkdir -p aptly
aws s3 sync s3://packages.flapjack.io/aptly aptly --acl private --region us-east-1

# Create all components for the distro release if they don't exist
for component in ${VALID_COMPONENTS}; do
  if ! aptly -config=aptly.conf repo show flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-${component} &>/dev/null ; then
    aptly -config=aptly.conf repo create -distribution ${DISTRO_RELEASE} -architectures="i386,amd64" -component=${component} flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-${component}
  fi
; done

if ! aptly -config=aptly.conf repo add flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-${DISTRO_COMPONENT} pkg/flapjack_${FLAPJACK_FULL_VERSION}~${DATE}-${FLAPJACK_BUILD_REF}*.deb ; then
  echo "Error adding deb to repostory" ; exit $?
fi

# Try updating the published repository for all components of the major version of the given distro release, otherwise do the first publish
if ! aptly -config=aptly.conf -gpg-key="803709B6" publish update ${DISTRO_RELEASE} ${FLAPJACK_MAJOR_VERSION} ; then
  # eg aptly publish repo -architectures="i386,amd64" -gpg-key="803709B6"  -component=, flapjack-1.0-trusty-main flapjack-1.0-trusty-experimental 1.0
  publish_cmd='aptly -config=aptly.conf publish repo -architectures="i386,amd64" -gpg-key="803709B6" -component=, '
  for component in ${VALID_COMPONENTS}; do publish_cmd+="flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-${component} "; done
  publish_cmd+=" ${FLAPJACK_MAJOR_VERSION}"
  eval $publish_cmd
fi

# Create directory index files for published packages
cd aptly/public
if ! ${PWD}/../../create_directory_listings . ; then
  echo "Directory indexes failed to create"
fi
cd -

aws s3 sync aptly s3://packages.flapjack.io/aptly --acl private --region us-east-1

aws s3 sync aptly/public s3://packages.flapjack.io/deb --acl public-read --region us-east-1
