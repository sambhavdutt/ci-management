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
echo "------> Clone fabric & Build images"

rm -rf ${WORKSPACE}/gopath/src/github.com/hyperledger/fabric
WD="${WORKSPACE}/gopath/src/github.com/hyperledger/fabric"

if [[ "$GERRIT_BRANCH" = "release-1.0" || "$GERRIT_BRANCH" = "release-1.1" ]]; then
   ARCH=$(uname -m) # x86_64, s390x, ppc64le
else
   ARCH=$(dpkg --print-architecture) # amd64
fi

REPO_NAME=fabric
git clone git://cloud.hyperledger.org/mirror/$REPO_NAME $WD
cd $WD || exit

####################
#
# error check
#
####################
err_Check() {
echo "ERROR !!!! --------> $1 <---------"
exit 1
}

####################
#
# export go version
#
####################

export_Go() {
GO_VER=`cat ci.properties | grep GO_VER | cut -d "=" -f 2`
OS_VER=$(dpkg --print-architecture)
export GOROOT=/opt/go/go$GO_VER.linux.$OS_VER
export PATH=$GOROOT/bin:$PATH
echo "------> GO_VER" $GO_VER
}

#############################
#
# Checkout to GERRIT_BRANCH
#
#############################

if [[ "$GERRIT_BRANCH" = *"release-"* ]]; then # any release branch
      echo "-----> Checkout to $GERRIT_BRANCH branch"
      git checkout $GERRIT_BRANCH
fi
echo "------> $GERRIT_BRANCH"
echo

#sed -i -e 's/127.0.0.1:7050\b/'"orderer:7050"'/g' $WD/common/configtx/tool/configtx.yaml
FABRIC_COMMIT=$(git log -1 --pretty=format:"%h")
echo "------> FABRIC_COMMIT: $FABRIC_COMMIT"

####################
#
# Call export_Go()
#
####################

export_Go

############################
#
# Publish unstable npm
#
############################

npmPublish() {
if [[ "$CURRENT_TAG" = *"skip"* ]]; then
   echo "----> Don't publish npm modules on skip tag"
 elif [[ "$CURRENT_TAG" = *"unstable"* ]]; then
    echo
    UNSTABLE_VER=$(npm dist-tags ls "$1" | awk "/$CURRENT_TAG"":"/'{
    ver=$NF
    sub(/.*\./,"",rel)
    sub(/\.[[:digit:]]+$/,"",ver)
    print ver}')
    echo "===> UNSTABLE VERSION --> $UNSTABLE_VER"

    # Get the unstable version of $CURRNT_TAG from npm
    UNSTABLE_INCREMENT=$(npm dist-tags ls "$1" | awk "/$CURRENT_TAG"":"/'{
    ver=$NF
    rel=$NF
    sub(/.*\./,"",rel)
    sub(/\.[[:digit:]]+$/,"",ver)
    print ver"."rel+1}')

    # Get last digit of the unstable version of $CURRENT_TAG
    UNSTABLE_INCREMENT=$(echo $UNSTABLE_INCREMENT| rev | cut -d '.' -f 1 | rev)
    echo "--------> UNSTABLE_INCREMENT : $UNSTABLE_INCREMENT"

    # Append last digit with the package.json version
    export UNSTABLE_INCREMENT_VERSION=$RELEASE_VERSION.$UNSTABLE_INCREMENT
    echo "--------> UNSTABLE_INCREMENT_VERSION" $UNSTABLE_INCREMENT_VERSION

    # Replace existing version with $UNSTABLE_INCREMENT_VERSION
    sed -i 's/\(.*\"version\"\: \"\)\(.*\)/\1'$UNSTABLE_INCREMENT_VERSION\"\,'/' package.json
    npm publish --tag $CURRENT_TAG

 else
      echo "----> Publish $CURRENT_TAG from fabric-sdk-node-npm-release-x86_64"
fi
}

##########################
#
# Fetch release version
#
##########################

versions() {
  # Get the unstable tag from package.json
  CURRENT_TAG=$(cat package.json | grep tag | awk -F\" '{ print $4 }')
  echo "===> Current TAG --> $CURRENT_TAG"

  # Get the version from package.json
  RELEASE_VERSION=$(cat package.json | grep version | awk -F\" '{ print $4 }')
  echo "===> Current Version --> $RELEASE_VERSION"

}

if [[ "$GERRIT_BRANCH" = "release-1.0" ]]; then # release-1.0 branch
        make docker || err_Check "make docker failed"
        echo
        docker images | grep hyperledger

elif [[ "$GERRIT_BRANCH" = "release-1.1" ]]; then # release-1.1 branch
     for IMAGES in peer-docker orderer-docker; do
        make $IMAGES || err_Check "make $IMAGES failed"
     done
        echo
         PREV_VERSION=`cat Makefile | grep BASEIMAGE_RELEASE= | awk -F= '{print $NF}'`
         docker pull hyperledger/fabric-couchdb:$ARCH-$PREV_VERSION
         docker tag hyperledger/fabric-couchdb:$ARCH-$PREV_VERSION hyperledger/fabric-couchdb
         docker images | grep hyperledger
else
     for IMAGES in peer-docker orderer-docker ccenv; do
         make $IMAGES || err_Check "make $IMAGES failed"
     done
         PREV_VERSION=`cat Makefile | grep BASEIMAGE_RELEASE= | awk -F= '{print $NF}'`
         docker pull hyperledger/fabric-couchdb:$ARCH-$PREV_VERSION
         docker tag hyperledger/fabric-couchdb:$ARCH-$PREV_VERSION hyperledger/fabric-couchdb
         echo "-----> Docker Images List"
         echo
         make docker-list && docker images | grep hyperledger/fabric-couchdb || true
fi

echo
echo "------> Clone & Build fabric-ca repository"

# Delete fabric-ca directory incase if build starts without destroy the x86,z build nodes
rm -rf ${WORKSPACE}/gopath/src/github.com/hyperledger/fabric-ca

WD="${WORKSPACE}/gopath/src/github.com/hyperledger/fabric-ca"
CA_REPO_NAME=fabric-ca
git clone ssh://hyperledger-jobbuilder@gerrit.hyperledger.org:29418/$CA_REPO_NAME $WD
cd $WD || exit

if [[ "$GERRIT_BRANCH" = *"release-"* ]]; then # any release branch
      echo "------> Checkout to $GERRIT_BRANCH branch"
      git checkout $GERRIT_BRANCH
fi

echo "------> $GERRIT_BRANCH"
CA_COMMIT=$(git log -1 --pretty=format:"%h")
echo "------> CA_COMMIT: $CA_COMMIT"
# call export_Go()
export_Go
echo "------> Build docker-fabric-ca Image"
make docker-fabric-ca || err_check "make docker-fabric-ca failed"
docker images | grep hyperledger/fabric-ca || true

if [[ "$GERRIT_BRANCH" = "master" || "$GERRIT_BRANCH" = "release-1.3" || "$ARCH" != "s390x" ]]; then

       #####################################
       # Pull fabric-chaincode-javaenv Image

       NEXUS_URL=nexus3.hyperledger.org:10001
       ORG_NAME="hyperledger/fabric"
       IMAGE=javaenv
       if [ "$GERRIT_BRANCH" = "master" ]; then
          export STABLE_VERSION=amd64-1.4.0-stable
          export JAVA_ENV_TAG=1.4.0
       else
          export STABLE_VERSION=amd64-1.3.0-stable
          export JAVA_ENV_TAG=1.3.1
       fi
       docker pull $NEXUS_URL/$ORG_NAME-$IMAGE:$STABLE_VERSION
       docker tag $NEXUS_URL/$ORG_NAME-$IMAGE:$STABLE_VERSION $ORG_NAME-$IMAGE
       docker tag $NEXUS_URL/$ORG_NAME-$IMAGE:$STABLE_VERSION $ORG_NAME-$IMAGE:amd64-$JAVA_ENV_TAG
       docker tag $NEXUS_URL/$ORG_NAME-$IMAGE:$STABLE_VERSION $ORG_NAME-$IMAGE:amd64-latest
       ######################################
       docker images | grep hyperledger/fabric-javaenv || true
else
       echo "========> SKIP: javaenv image is not available on $GERRIT_BRANCH and on $ARCH"
fi

echo
echo "------> START NODE TESTS"

cd ${WORKSPACE}/gopath/src/github.com/hyperledger/fabric-sdk-node/test/fixtures || exit
docker-compose up >> dockerlogfile.log 2>&1 &
sleep 30
docker ps -a

cd ${WORKSPACE}/gopath/src/github.com/hyperledger/fabric-sdk-node || exit

# Install nvm to install multi node versions
wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.2/install.sh | bash
# shellcheck source=/dev/null
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

echo "------> Install NodeJS"

# Checkout to GERRIT_BRANCH
if [[ "$GERRIT_BRANCH" = *"release-1.0"* ]]; then # Only on release-1.0 branch
    NODE_VER=6.9.5
    echo "------> Use $NODE_VER for release-1.0 branch"
    nvm install $NODE_VER

    # use nodejs 6.9.5 version
    nvm use --delete-prefix v$NODE_VER --silent
elif [[ "$GERRIT_BRANCH" = *"release-1.1"* || "$GERRIT_BRANCH" = *"release-1.2"* ]]; then # only on release-1.2 or release-1.1 branches
    NODE_VER=8.9.4
    echo "------> Use $NODE_VER for release-1.1 and release-1.2 branches"
    nvm install $NODE_VER
    # use nodejs 8.9.4 version
    nvm use --delete-prefix v$NODE_VER --silent
else
    NODE_VER=8.11.3
    echo "------> Use $NODE_VER for master"
    nvm install $NODE_VER
    # use nodejs 8.11.3 version
    nvm use --delete-prefix v$NODE_VER --silent
fi

echo "npm version ------> $(npm -v)"
echo "node version ------> $(node -v)"

npm install || err_Check "ERROR!!! npm install failed"
npm config set prefix ~/npm && npm install -g gulp && npm install -g istanbul
gulp || err_Check "ERROR!!! gulp failed"
gulp ca || err_Check "ERROR!!! gulp ca failed"
rm -rf node_modules/fabric-ca-client && npm install || err_Check "ERROR!!! npm install failed"

echo "------> Run node headless & e2e tests"
gulp test

# copy debug log file to $WORKSPACE directory
if [ $? == 0 ]; then

       # Copy Debug log to $WORKSPACE
       cp /tmp/hfc/test-log/*.log $WORKSPACE
else
       # Copy Debug log to $WORKSPACE
       cp /tmp/hfc/test-log/*.log $WORKSPACE
       exit 1

fi

######################################
#
# Currently publishing npm from x86_64
#
######################################
ARCH=$(uname -m)
if [[ "$ARCH" = "s390x" ]] || [[ "$ARCH" = "ppc64le" ]]; then
   echo "----> npm modules published only from x86_64 (x) platform, not publishing from $ARCH (z) now. <----"
else
   echo "----> Publish npm node modules from $ARCH <----"
   cd $WORKSPACE/gopath/src/github.com/hyperledger/fabric-sdk-node
   npm config set //registry.npmjs.org/:_authToken=$NPM_TOKEN
   cd fabric-ca-client
   versions
   npmPublish fabric-ca-client

   cd ../fabric-client
   versions
   npmPublish fabric-client

   if [ -d "../fabric-network" ]; then
     cd ../fabric-network
     versions
     npmPublish fabric-network
   fi
   if [ -d "../fabric-common" ]; then
     cd ../fabric-common
     versions
     npmPublish fabric-common
   fi

fi
