#!/bin/bash -eu
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

cd ${WORKSPACE}/gopath/src/github.com/hyperledger/fabric-chaincode-node
# Generate chaincode-node API docs
gulp docs
CHAINCODE_NODE_COMMIT=$(git rev-parse --short HEAD)
TARGET_REPO=$CHAINCODE_NODE_USERNAME.github.io.git
git clone https://github.com/$CHAINCODE_NODE_USERNAME/$TARGET_REPO

# Copy API docs to Target repository
cp -r docs/gen/* $CHAINCODE_NODE_USERNAME.github.io
cd $CHAINCODE_NODE_USERNAME.github.io
git add .
git commit -m "CHAINCODE_NODE commit - $CHAINCODE_NODE_COMMIT"
git config remote.gh-pages.url https://$CHAINCODE_NODE_USERNAME:$CHAINCODE_NODE_PASSWORD@github.com/$CHAINCODE_NODE_USERNAME/$TARGET_REPO

# Push API docs to Target repository
git push gh-pages master
