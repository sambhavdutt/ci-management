#!/bin/bash

# docker container list
CONTAINER_LIST=(peer0.org1 peer1.org1 peer0.org2 peer1.org2 peer0.org3 peer1.org3 orderer)
COUCHDB_CONTAINER_LIST=(couchdb0 couchdb1 couchdb2 couchdb3 couchdb4 couchdb5)

cd gopath/src/github.com/hyperledger/fabric-samples || exit
# copy /bin directory to fabric-samples
cp -r ${WORKSPACE}/gopath/src/github.com/hyperledger/fabric/release/linux-amd64/bin/ .

cd first-network || exit

# Create Logs directory
mkdir -p $WORKSPACE/Docker_Container_Logs

#Set INFO to DEBUG
sed -it 's/INFO/DEBUG/' base/peer-base.yaml

export PATH=gopath/src/github.com/hyperledger/fabric-samples/bin:$PATH

artifacts() {

    echo "---> Archiving generated logs"
    mkdir -p "$WORKSPACE/archives"
    mv "$WORKSPACE/Docker_Container_Logs" $WORKSPACE/archives/
}

# Capture docker logs of each container
logs() {

for CONTAINER in ${CONTAINER_LIST[*]}; do
    docker logs $CONTAINER.example.com >& $WORKSPACE/Docker_Container_Logs/$CONTAINER-$1.log
    echo
done

if [ ! -z $2 ]; then

    for CONTAINER in ${COUCHDB_CONTAINER_LIST[*]}; do
        docker logs $CONTAINER >& $WORKSPACE/Docker_Container_Logs/$CONTAINER-$1.log
        echo
    done
fi
}

copy_logs() {

# Call logs function
logs $2 $3

if [ $1 != 0 ]; then
    artifacts
    exit 1
fi
}

# Execute below tests
echo "------> BRANCH: " $GERRIT_BRANCH
if [ $GERRIT_BRANCH == "master" ]; then

	echo "############## BYFN,EYFN DEFAULT CHANNEL TEST####################"
	echo "#################################################################"

	echo y | ./byfn.sh -m down
	echo y | ./byfn.sh -m up -t 60
	echo y | ./eyfn.sh -m up -t 60
        copy_logs $1 default-channel
        echo y | ./eyfn.sh -m down
	echo
	echo "############## BYFN,EYFN CUSTOM CHANNEL TEST#############"
	echo "#########################################################"

	echo y | ./byfn.sh -m up -c custom-channel -t 60
	echo y | ./eyfn.sh -m up -c custom-channel -t 60
        copy_logs $1 custom-channel
	echo y | ./eyfn.sh -m down
	echo
	echo "############### BYFN,EYFN CUSTOME CHANNEL WITH COUCHDB TEST #############"
	echo "#########################################################################"

	echo y | ./byfn.sh -m up -c custom-channel-couch -s couchdb -t 60
	echo y | ./eyfn.sh -m up -c custom-channel-couch -s couchdb -t 60
        copy_logs $1 custom-channel-couch couchdb
	echo y | ./eyfn.sh -m down
	echo
	echo "############### BYFN,EYFN WITH NODE Chaincode. TEST ################"
	echo "###############################################################"

	echo y | ./byfn.sh -m up -l node -t 60
	echo y | ./eyfn.sh -m up -l node -t 60
        copy_logs $1 default-channel-node
	echo y | ./eyfn.sh -m down

else
	echo "############## BYFN,EYFN DEFAULT CHANNEL TEST####################"
	echo "#################################################################"
	echo y | ./byfn.sh -m down
        echo y | ./byfn.sh -m up -t 60
        copy_logs $1 default-channel
	echo y | ./byfn.sh -m down
        echo

        echo "############## BYFN,EYFN CUSTOM CHANNEL TEST#############"
        echo "#########################################################"
        echo y | ./byfn.sh -m up -c custom-channel -t 60
        copy_logs $1 custom-channel

	echo "############### BYFN,EYFN CUSTOME CHANNEL WITH COUCHDB TEST #############"
        echo "#########################################################################"
        echo y | ./byfn.sh -m down
	echo y | ./byfn.sh -m up -c custom-channel-couch -s couchdb -t 60
        copy_logs $1 custom-channel-couch couchdb
        echo y | ./byfn.sh -m down
fi
artifacts
