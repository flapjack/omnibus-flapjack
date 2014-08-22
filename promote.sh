#!/bin/bash
set -e

if [ $# -ne 1 ]; then
  echo "Usage: filename"
  echo "eg. candidate_flapjack_1.0.0~rc6~20140820210002-master-precise-1_amd64.deb"
  exit 2
fi

FILENAME=$1

IFS="_" read -ra VERSION_ARRAY <<< "${FILENAME}"

VERSION=${VERSION_ARRAY[2]}
DISTRO_RELEASE=$(echo ${VERSION} | cut -d '-' -f 3)
MAIN_VERSION=$(echo ${VERSION} | cut -d "~" -f 1)-${DISTRO_RELEASE}
FLAPJACK_MAJOR_VERSION=$(echo ${VERSION} | cut -d . -f 1,2)

if [ ! -e "pkg/${FILENAME}" ] ; then
  echo "Copying candidate package from s3"
  aws s3 cp s3://packages.flapjack.io/candidates/${FILENAME} . --acl public-read --region us-east-1
  retval=$?
  if [ ! "$retval" -eq "0" ] ; then
    echo "Couldn't upload package from pkg/${FILENAME}"
    exit $retval
  fi
fi

MAIN_FILENAME=${VERSION_ARRAY[1]}_${MAIN_VERSION}_${VERSION_ARRAY[3]}
cp ${FILENAME} ${MAIN_FILENAME}
echo "New package is at ${MAIN_FILENAME}"

echo "Retrieving aptly repo from S3"
mkdir -p aptly
aws s3 sync s3://packages.flapjack.io/aptly aptly --delete --acl public-read --region us-east-1

echo "Adding pkg/${FILENAME} to the flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-main repo"
aptly -config=aptly.conf repo add flapjack-${FLAPJACK_MAJOR_VERSION}-${DISTRO_RELEASE}-main ${MAIN_FILENAME}
retval=$?
if [ ! "$retval" -eq "0" ] ; then
  echo "Error adding deb to repostory, aptly returned ${retval}"
  exit $retval
fi

echo "Updating the already published repository ${DISTRO_RELEASE}"
# Aptly checks the inode number to determine if packages are the same.  As we sync from S3, our inode numbers change, so identical packages are deemed different unless we use -force-overwrite
aptly -config=aptly.conf -gpg-key="803709B6" -force-overwrite=true publish update ${DISTRO_RELEASE} ${FLAPJACK_MAJOR_VERSION}

echo "Creating directory index files for published packages"
cd aptly/public
../../create_directory_listings .
if [ ! "$retval" -eq "0" ] ; then
  echo "Directory indexes failed to be created"
  exit $retval
fi

cd -

echo "Syncing the aptly db up to S3"
aws s3 sync aptly s3://packages.flapjack.io/aptly --delete --acl public-read --region us-east-1

echo "Syncing the public packages repo up to S3"
aws s3 sync aptly/public s3://packages.flapjack.io/deb --delete --acl public-read --region us-east-1

echo "Remove the old s3 package"
aws s3 rm s3://packages.flapjack.io/candidates/${FILENAME}

echo "Done"
