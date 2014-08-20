#!/bin/bash
set -e

if [ $# -ne 1 ]; then
  echo "Usage: filename"
  echo "eg. flapjack_1.0.0-precise_amd64.deb"
  exit 2
fi

FILENAME=$1

IFS="_" read -ra VERSION_ARRAY <<< "${FILENAME}"

VERSION=${VERSION_ARRAY[1]}
DISTRO_RELEASE=$(echo ${VERSION} | cut -d '-' -f 2)
FLAPJACK_MAJOR_VERSION=$(echo ${VERSION} | cut -d . -f 1,2)

if [ ! -f pkg/${FILENAME} ]; then
  echo "Couldn't find package at pkg/${FILENAME}"
  exit 3
fi

echo "Putting packages into aptly repo, syncing with S3"
mkdir -p aptly
aws s3 sync s3://packages.flapjack.io/aptly aptly --delete --acl public-read --region us-east-1

echo "Adding pkg/${FILENAME} to the flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-main repo"
if ! aptly -config=aptly.conf repo add flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-main pkg/${FILENAME} ; then
  echo "Error adding deb to repostory" ; exit $?
fi

echo "Repository already published, attempting an update"
# Aptly checks the inode number to determine if packages are the same.  As we sync from S3, our inode numbers change, so identical packages are deemed different.
aptly -config=aptly.conf -gpg-key="803709B6" -force-overwrite=true publish update ${DISTRO_RELEASE} ${FLAPJACK_MAJOR_VERSION}

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
