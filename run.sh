#!/bin/bash
set -e

if [ $# -ne 2 ]; then
  echo "Usage: `basename $0` build_ref distro_release"
  echo "eg. `basename $0` 4deb3ef precise"
  exit 2
fi

DATE=$(date +%Y%m%d%H%M%S)
FLAPJACK_BUILD_REF=$1
DISTRO_RELEASE=$2
VALID_COMPONENTS=(main experimental)

echo "Determining FLAPJACK_BUILD_TAG..."
FLAPJACK_FULL_VERSION=$(wget -qO - https://raw.githubusercontent.com/flapjack/flapjack/${FLAPJACK_BUILD_REF}/lib/flapjack/version.rb | grep 'VERSION' | cut -d '"' -f 2)
: ${FLAPJACK_FULL_VERSION:?"Incorrect build_ref.  Tags should be specified as 'v1.0.0rc3'" }
FLAPJACK_MAJOR_VERSION=$(echo $FLAPJACK_FULL_VERSION |  cut -d . -f 1,2)
#put a ~ separator in before any alpha parts of the version string, eg "1.0.0rc3" -> "1.0.0~rc3"
FLAPJACK_FULL_VERSION=$(echo $FLAPJACK_FULL_VERSION | sed -e 's/\([a-z]\)/~\1/')
FLAPJACK_PACKAGE_VERSION="${FLAPJACK_FULL_VERSION}~${DATE}-${FLAPJACK_BUILD_REF}-${DISTRO_RELEASE}"

echo
echo "FLAPJACK_FULL_VERSION: ${FLAPJACK_FULL_VERSION}"
echo "FLAPJACK_BUILD_REF: ${FLAPJACK_BUILD_REF}"
echo "FLAPJACK_PACKAGE_VERSION: ${FLAPJACK_PACKAGE_VERSION}"
echo "DISTRO_RELEASE: ${DISTRO_RELEASE}"
echo
echo "Starting Docker container..."


time sudo docker run -t --attach stdout --attach stderr --detach=false \
-e "FLAPJACK_BUILD_REF=${FLAPJACK_BUILD_REF}" \
-e "FLAPJACK_PACKAGE_VERSION=${FLAPJACK_PACKAGE_VERSION}" \
-e "DISTRO_RELEASE=${DISTRO_RELEASE}" \
flapjack/omnibus-ubuntu bash -c \
'cd omnibus-flapjack ; \
git pull ; \
bundle install --binstubs ; \
bin/omnibus build --log-level=info flapjack ; \
cd /omnibus-flapjack/pkg ; \
ls -ct1 | head -n 1 > /tmp/experimental_deb ; \
EXPERIMENTAL_VERSION=$(echo $(cut -d _ -f 2 /tmp/experimental_deb | cut -d "-" -f -3)) ; \
MAIN_VERSION=$(echo ${FLAPJACK_PACKAGE_VERSION} | cut -d "~" -f 1) ; \
MAIN_DEB_FILENAME=$(cut -d _ -f 1 /tmp/experimental_deb)_${MAIN_VERSION}-${DISTRO_RELEASE}_$(cut -d _ -f 3 /tmp/experimental_deb) ; \
dpkg-deb -R $(cat /tmp/experimental_deb) repackage ; \
sed -i s#${EXPERIMENTAL_VERSION}-1#${MAIN_VERSION}#g repackage/DEBIAN/control ; \
sed -i s#${EXPERIMENTAL_VERSION}#${MAIN_VERSION}#g repackage/opt/flapjack/version-manifest.txt ; \
dpkg-deb -b repackage ${MAIN_DEB_FILENAME}'

echo "Docker run completed."
sleep 10 # one time I got "Could not find the file /omnibus-flapjack/pkg in container" and a while later it worked fine
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
    if ! sudo apt-get install -y aptly ; then
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
aws s3 sync s3://packages.flapjack.io/aptly aptly --delete --acl public-read --region us-east-1

echo "Creating all components for the distro release if they don't exist"
for component in "${VALID_COMPONENTS[@]}"; do
  if ! aptly -config=aptly.conf repo show flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-${component} &>/dev/null ; then
    aptly -config=aptly.conf repo create -distribution ${DISTRO_RELEASE} -architectures="i386,amd64" -component=${component} flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-${component}
  fi
done

echo "Adding pkg/flapjack_${FLAPJACK_PACKAGE_VERSION}*.deb to the flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-experimental repo"
if ! aptly -config=aptly.conf repo add flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-experimental pkg/flapjack_${FLAPJACK_PACKAGE_VERSION}*.deb ; then
  echo "Error adding deb to repostory" ; exit $?
fi

echo "Attempting the first publish for all components of the major version of the given distro release"
publish_cmd='aptly -config=aptly.conf publish repo -architectures="i386,amd64" -gpg-key="803709B6" -component=, '
for component in ${VALID_COMPONENTS[@]}; do publish_cmd+="flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-${component} "; done
publish_cmd+=" ${FLAPJACK_MAJOR_VERSION}"
if ! eval $publish_cmd &>/dev/null ; then
  echo "Repository already published, attempting an update"
  # Aptly checks the inode number to determine if packages are the same.  As we sync from S3, our inode numbers change, so identical packages are deemed different.
  aptly -config=aptly.conf -gpg-key="803709B6" -force-overwrite=true publish update ${DISTRO_RELEASE} ${FLAPJACK_MAJOR_VERSION}
fi

echo "Creating directory index files for published packages"
cd aptly/public
if ! ../../create_directory_listings . ; then
  echo "Directory indexes failed to create"
fi
cd -

echo "Syncing the aptly db up to S3"
aws s3 sync aptly s3://packages.flapjack.io/aptly --delete --acl public-read --region us-east-1

echo "Syncing the public packages repo up to S3"
aws s3 sync aptly/public s3://packages.flapjack.io/deb --delete --acl public-read --region us-east-1

echo "Done"
