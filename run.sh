#!/bin/bash
set -e

date=$(date +%Y%m%d%H%M%S)
type=${type:-experimental}
FLAPJACK_BUILD_REF=${FLAPJACK_BUILD_REF:-master}

docker run -i -t -e "FLAPJACK_BUILD_REF=${FLAPJACK_BUILD_REF}" \
-e "FLAPJACK_PACKAGE_VERSION=${FLAPJACK_BUILD_TAG}-${date}-${FLAPJACK_BUILD_REF}" \
flapjack/omnibus-ubuntu bash -c \
"cd omnibus-flapjack ; \
git pull ; \
bundle install --binstubs ; \
bin/omnibus build --log-level=info flapjack ; \
bash"

container_id=`docker ps -l -q`
docker cp ${container_id}:/omnibus-flapjack/pkg .
docker rm ${container_id}

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
  "S3PublishEndpoints": {
    "packages.flapjack.io": {
      "region": "ap-southeast-2",
      "bucket": "packages.flapjack.io",
      "prefix": "aptly",
      "acl": "public-read"
    }
  }
}
EOF
  fi

fi
# End aptly installation

if ! aptly -config=aptly.conf -distribution ${type} repo create flapjack-${type} 2>/dev/null; then
  echo "Flapjack repository already exists."
fi

if ! aptly -config=aptly.conf repo add flapjack-${type} pkg/flapjack_${FLAPJACK_BUILD_TAG}-${date}-${FLAPJACK_BUILD_REF}.deb ; then
  echo "Error adding deb to repostory" ; exit $? ;
fi

if ! aptly -config=aptly.conf -gpg-key="01B76104" publish repo flapjack-${type} s3:packages.flapjack.io: ; then
  echo "Error publishing to S3." ; exit $? ;
fi
