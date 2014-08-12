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

echo "Determining FLAPJACK_BUILD_TAG..."

FLAPJACK_BUILD_TAG=$(wget -qO - https://raw.githubusercontent.com/flapjack/flapjack/${FLAPJACK_BUILD_REF}/lib/flapjack/version.rb | grep 'VERSION' | cut -d '"' -f 2)
: ${FLAPJACK_BUILD_TAG:?"Incorrect build_ref.  Tags should be specified as 'v1.0.0rc3'" }

echo
echo "FLAPJACK_BUILD_TAG: ${FLAPJACK_BUILD_TAG}"
echo "FLAPJACK_BUILD_REF: ${FLAPJACK_BUILD_REF}"
echo "FLAPJACK_PACKAGE_VERSION: ${FLAPJACK_PACKAGE_VERSION}"
echo
echo "Starting Docker container..."

sudo docker run -i -t -e "FLAPJACK_BUILD_REF=${FLAPJACK_BUILD_REF}" \
-e "FLAPJACK_PACKAGE_VERSION=${FLAPJACK_BUILD_TAG}~${DATE}-${FLAPJACK_BUILD_REF}" \
flapjack/omnibus-ubuntu bash -c \
"cd omnibus-flapjack ; \
git pull ; \
bundle install --binstubs ; \
bin/omnibus build --log-level=info flapjack"

echo "Docker run completed."
echo "Retrieving package from the container"
container_id=`sudo docker ps -l -q`
sudo docker cp ${container_id}:/omnibus-flapjack/pkg .

echo "Purging the container"
sudo docker rm ${container_id}

# Check if awscli exists
if ! hash aws 2>/dev/null; then
  echo "Installing awscli"
  sudo apt-get install -y awscli
fi

# Check if aptly exists
if ! hash aptly 2>/dev/null; then
  if [ -f /etc/debian_version ]; then
    echo "Installing aptly"
    echo 'deb http://repo.aptly.info/ squeeze main' | sudo tee  /etc/apt/sources.list.d/aptly.list
    gpg --keyserver keys.gnupg.net --recv-keys 2A194991
    gpg -a --export 2A194991 | sudo apt-key add -

    sudo apt-get update
    if !sudo apt-get install -y aptly ; then
      echo "Error installing aptly." ; exit $? ;
    fi

  fi
fi

if [ ! -e aptly.conf ] ; then
  echo "Creating aptly.conf"
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
# End aptly installation

echo "Putting packages into aptly repo, syncing with S3"
mkdir -p aptly
aws s3 sync s3://packages.flapjack.io/aptly aptly --acl private --region us-east-1

echo "Creating the repo if it doesn't exist"
if ! aptly -config=aptly.conf repo show flapjack-${DISTRO_RELEASE} 2>/dev/null ; then
  aptly -config=aptly.conf repo create --distribution ${DISTRO_RELEASE} -architectures="i386,amd64" -component=${DISTRO_COMPONENT} flapjack-${DISTRO_RELEASE}
fi

echo "Adding pkg/flapjack_${FLAPJACK_BUILD_TAG}~${DATE}-${FLAPJACK_BUILD_REF}*.deb to the repo"
if ! aptly -config=aptly.conf repo add flapjack-${DISTRO_RELEASE} pkg/flapjack_${FLAPJACK_BUILD_TAG}~${DATE}-${FLAPJACK_BUILD_REF}*.deb ; then
  echo "Error adding deb to repostory" ; exit $?
fi

echo "Trying to update the published repository, otherwise doing the first publish"
if ! aptly -config=aptly.conf -gpg-key="803709B6" publish update ${DISTRO_RELEASE} ; then
  aptly -config=aptly.conf -component=${DISTRO_COMPONENT} -architectures="i386,amd64" -gpg-key="803709B6" publish repo flapjack-${DISTRO_RELEASE}
fi

echo "Creating directory index files for published packages"
if ! ${PWD}/create_directory_listings aptly/public ; then
  echo "Directory indexes failed to create"
fi

echo "Syncing the aptly db up to S3"
aws s3 sync aptly s3://packages.flapjack.io/aptly --acl private --region us-east-1

echo "Syncing the public repo up to S3"
aws s3 sync aptly/public s3://packages.flapjack.io/deb --acl public-read --region us-east-1
