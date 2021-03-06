#!/bin/bash -e
#
# SPDX-License-Identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 IBM Corporation, The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License 2.0
# which accompanies this distribution, and is available at
# https://www.apache.org/licenses/LICENSE-2.0
##############################################################################
set -o pipefail

# Build fabric images
cd ${WORKSPACE}/gopath/src/github.com/hyperledger/fabric || exit
NEXUS_URL=nexus3.hyperledger.org:10002
# get the GOARCH value
ARCH=$(dpkg --print-architecture) # amd64, s390x
if [ "$GERRIT_BRANCH" = "release-1.0" ] || [ "$GERRIT_BRANCH" = "release-1.1" ]; then
       ARCH=x86_64
else
      ARCH=$(dpkg --print-architecture)
      echo "----------> ARCH:" $ARCH
fi

# Build docker images with $PUSH_VERSION (ex: 1.2.0-rc1)
echo "========================"
echo "======> BUILD DOCKER IMAGES <======="
make docker PROJECT_VERSION=$PUSH_VERSION
if [ $? != 0 ]; then
     echo "--------> make docker failed"
     exit 1
fi

echo "----------> List all fabric docker images"
docker images

# publish fabric and thirdparty docker images from release-1.0 branch
if [[ $GERRIT_BRANCH = "release-1.0" ]]; then
    for IMAGES in peer orderer couchdb ccenv kafka zookeeper tools; do
       echo "==> $IMAGES"
       docker push $NEXUS_URL/$ORG_NAME-$IMAGES:$ARCH-$PUSH_VERSION
       echo
       echo "==> $NEXUS_URL/$ORG_NAME-$IMAGES:$ARCH-$PUSH_VERSION"
    done
else
# publish fabric docker images otherthan release-1.0 branch
# thirdparty images code has been moved to fabric-baseimage repo
    for IMAGES in peer orderer tools ccenv; do
       docker tag hyperledger/fabric-$IMAGES:$ARCH-$PUSH_VERSION $NEXUS_URL/hyperledger/fabric-$IMAGES:$ARCH-$PUSH_VERSION
       docker push $NEXUS_URL/hyperledger/fabric-$IMAGES:$ARCH-$PUSH_VERSION
       echo "--------> Push fabric Image version:" $NEXUS_URL/hyperledger/fabric-$IMAGES:$ARCH-$PUSH_VERSION
    done
fi
