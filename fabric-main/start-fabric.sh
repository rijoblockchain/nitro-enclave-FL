#!/usr/bin/env bash

# Builds the main Fabric network on a Kubernetes cluster.
# This script can be rerun if it fails. It will simply rerun the K8s commands, which will have
# no impact if they've been run previously

set -e


function main {
    echo "Beginning setup of Hyperledger Fabric on Kubernetes for hlf ..."

    cd $HOME/$REPO/fabric-main
    source util-prep.sh
    copyScripts $HOME $REPO $DATADIR
    makeDirs $DATADIR
    source $SCRIPTS/env.sh
    cd $HOME/$REPO/fabric-main
    source utilities.sh
    makeDirsForOrg $DATADIR
    genTemplates $HOME $REPO
    createNamespaces $HOME $REPO
    startPVC $HOME $REPO
    startRCA $HOME $REPO
    sleep 10s
    if [ $FABRIC_NETWORK_TYPE == "PROD" ]; then
        startOrdererNLB $HOME $REPO
        startAnchorPeerNLB $HOME $REPO
    fi
    startRegisterOrderers $HOME $REPO
    startRegisterPeers $HOME $REPO
    updateChannelArtifacts $HOME $REPO
    startOrderer $HOME $REPO
    createBuilderConfig $HOME $REPO
    startCLIs $HOME $REPO
    startPeers $HOME $REPO
    sleep 30s
    createAppChannel $HOME $REPO
    sleep 10s
    joinChannel $HOME $REPO
    sleep 10s
    updateAnchorPeer $HOME $REPO
    packagingChaincode $HOME $REPO $DATADIR
    installingChaincode $HOME $REPO
    queryInstalled $HOME $REPO
    deployChaincode $HOME $REPO $DATADIR
    approveChaincode $HOME $REPO $DATADIR
    checkCommitReadiness $HOME $REPO $DATADIR
    commitChaincode $HOME $REPO $DATADIR
    queryCommitted $HOME $REPO

    # if only -- init-required is provided during commit
    initChaincode $HOME $REPO

    createConfigMap $HOME $REPO
    createAPI $HOME $REPO

    source $HOME/$REPO/non-remote-org/copy-tofrom-S3-orderer.sh $HOME $REPO $DATADIR 
    #createS3BucketForOrderer
    copyEnvToS3
    sleep 10s
    copyOrdererPEMToS3
    sleep 10s
    copyChannelGenesisToS3
    
    
}

SDIR=$(dirname "$0")
REPO=healthcare-hlf-k8
DATADIR=/opt/share/efs
#DATADIR=/opt/share
SCRIPTS=$DATADIR/scripts
main 