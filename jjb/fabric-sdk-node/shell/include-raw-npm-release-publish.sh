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

# This script supports only stable fabric-client and fabric-ca-client npm modules
# publish snapshot version through merge jobs

set -o pipefail

npmPublish() {
  if [[ "$CURRENT_TAG" = *"unstable"* ]] || [[ "$CURRENT_TAG" = *"skip"* ]]; then
    echo "----> Ignore the release as this is an unstable release"
    echo "----> Merge jobs publishes the unstable releases"
  else
      if [[ "$RELEASE_VERSION" =~ alpha*|preview*|beta*|rc*|^[0-9].[0-9].[0-9]$ ]]; then
        echo "===> PUBLISH --> $RELEASE_VERSION"
        npm publish --tag $CURRENT_TAG
      else
        echo "$RELEASE_VERSION: No such release."
        exit 1
      fi
  fi
}

versions() {

  CURRENT_TAG=$(cat package.json | grep tag | awk -F\" '{ print $4 }')
  echo "===> Current Tag --> $CURRENT_TAG"

  RELEASE_VERSION=$(cat package.json | grep version | awk -F\" '{ print $4 }')
  echo "===> Current RELEASE VERSION --> $RELEASE_VERSION"
}

cd $WORKSPACE/gopath/src/github.com/hyperledger/fabric-sdk-node
npm config set //registry.npmjs.org/:_authToken=$NPM_TOKEN

: '
cd fabric-ca-client
versions
npmPublish fabric-ca-client

cd ../fabric-client
versions
npmPublish fabric-client

if [ -d "../fabric-common" ]; then
  cd ../fabric-common
  versions
  npmPublish fabric-common
fi
'
cd fabric-network
versions
npmPublish fabric-network

