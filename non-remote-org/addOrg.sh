#!/usr/bin/env bash

# Adds new Org in the main Fabric network on a Kubernetes cluster.


NEW_ORG=$3
NEW_DOMAIN=$1

set -e


function main {
    echo "Beginning setup of non-remote org on Hyperledger Fabric on Kubernetes ..."
    cd $HOME/$REPO
    source fabric-main/util-prep.sh
    source fabric-main/utilities.sh
    #updateRepo $HOME $REPO
    updateEnvForNewOrg $HOME $REPO $DATADIR $1 $2 $3
    mkdir -p $DATADIR/organizations/fabric-ca/$3RCA
    mergeEnv $HOME $REPO $DATADIR $MERGEFILE
    source prerequisite/scripts/env.sh $1 $2 $3
    genTemplates $HOME $REPO $1 $2 $3 $4
    #createNamespaces $HOME $REPO
    #startPVC $HOME $REPO
    startNewOrgRCA $HOME $REPO
    startRegisterPeers $HOME $REPO
    source $HOME/$REPO/non-remote-org/copy-tofrom-S3-neworg.sh $1 $2 $3
    copyEnvFromS3
    #createS3BucketForNewOrg
    #copyCertsToS3 $HOME $REPO $1
    source $HOME/$REPO/non-remote-org/create-channel-config.sh $HOME $REPO $1 $2 $3
    sleep 10s
    source $HOME/$REPO/non-remote-org/sign-channel-config.sh $HOME $REPO
    sleep 10s
    source $HOME/$REPO/non-remote-org/update-channel-config.sh $HOME $REPO
    sleep 10s

    getDomain $2
    source $HOME/$REPO/prerequisite/scripts/copy-tofrom-S3-orderer.sh $DOMAIN $2 
    copyEnvToS3 $2 $DATADIR

    cp $HOME/$REPO/prerequisite/scripts/env.sh $SCRIPTS
    source $HOME/$REPO/fabric-main/utilities.sh $1 $2 $3
    startCLIs $HOME $REPO
    startPeers $HOME $REPO
    sleep 30s
    joinChannel $HOME $REPO
    sleep 10s
    
    installingChaincode $HOME $REPO
    queryInstalled $HOME $REPO
    approveChaincode $HOME $REPO $DATADIR
    
    createConnectionProfile $DATADIR $3

    createConfigMap $HOME $REPO

    createAPI $HOME $REPO

    #createFrontend $HOME $REPO

    # createConfigMapExplorer $REPO $DATADIR $3
    # createExplorerDB $HOME $REPO
    # createExplorer $HOME $REPO

    echo "New Org is added"


    
}



SDIR=$(dirname "$0")
REPO=healthcare-blockchain-3.0-k8
#DATADIR=/opt/share2/pvc-9f636297-528f-4ea1-952c-d6e5e01d5fde
DATADIR=/opt/share
SCRIPTS=$DATADIR/scripts
MERGEFILE=non-remote-org/env-org.sh

cat > ${DATADIR}/organizations/fabric-ca/ordererRCA/updateorg << EOF
${NEW_ORG}
EOF

main $1 $2 $3 $4

