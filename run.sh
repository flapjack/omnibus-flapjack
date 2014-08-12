#!/bin/bash
set -e

args=("$@")
if [ $# -ne 3 ]
then
  echo "Usage: `basename $0` build_ref distro_release distro_component"
  echo "eg. `basename $0` master precise experimental"
  exit 2
fi

DATE=$(date +%Y%m%d%H%M%S)
FLAPJACK_BUILD_REF=$1
DISTRO_RELEASE=$2
DISTRO_COMPONENT=$3
# FIXME: Find this from lib/flapjack/version.rb
FLAPJACK_BUILD_TAG='1.0.0~rc3'

docker run -i -t -e "FLAPJACK_BUILD_REF=${FLAPJACK_BUILD_REF}" \
-e "FLAPJACK_PACKAGE_VERSION=${FLAPJACK_BUILD_TAG}~${DATE}-${FLAPJACK_BUILD_REF}" \
flapjack/omnibus-ubuntu bash -c \
"cd omnibus-flapjack ; \
git pull ; \
bundle install --binstubs ; \
bin/omnibus build --log-level=info flapjack"

container_id=`docker ps -l -q`
docker cp ${container_id}:/omnibus-flapjack/pkg .
docker rm ${container_id}

# Check if awscli exists
if not hash aws 2>/dev/null; then
  apt-get install -y awscli
fi

# Check if aptly exists
if not hash aptly 2>/dev/null; then
  if [ -f /etc/debian_version ]; then
    echo 'deb http://repo.aptly.info/ squeeze main' > /etc/apt/sources.list.d/aptly.list
    gpg --keyserver keys.gnupg.net --recv-keys 2A194991
    gpg -a --export 2A194991 | apt-key add -

    apt-get update
    apt-get install -y aptly

    if !apt-get install -y aptly ; then
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

# Create the repo if it doesn't exist
if ! aptly -config=aptly.conf repo show flapjack-${DISTRO_RELEASE} 2>/dev/null ; then
  aptly -config=aptly.conf repo create --distribution ${DISTRO_RELEASE} -architectures="i386,amd64" -component=${DISTRO_COMPONENT} flapjack-${DISTRO_RELEASE}
fi

if ! aptly -config=aptly.conf repo add flapjack-${DISTRO_RELEASE} pkg/flapjack_${FLAPJACK_BUILD_TAG}~${DATE}-${FLAPJACK_BUILD_REF}*.deb ; then
  echo "Error adding deb to repostory" ; exit $?
fi

# Try updating the published repository, otherwise do the first publish
if ! aptly -config=aptly.conf -gpg-key="803709B6" publish update ${DISTRO_RELEASE} ; then
  aptly -config=aptly.conf -component=${DISTRO_COMPONENT} -architectures="i386,amd64" -gpg-key="803709B6" publish repo flapjack-${DISTRO_RELEASE}
fi

# Create directory index files for published packages
if ! ${PWD}/create_directory_listings aptly/public ; then
  echo "Directory indexes failed to create"
fi

aws s3 sync aptly s3://packages.flapjack.io/aptly --acl private --region us-east-1

aws s3 sync aptly/public s3://packages.flapjack.io/deb --acl public-read --region us-east-1
