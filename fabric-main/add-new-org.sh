#!/usr/bin/env bash

set -e


function main {
    NEW_ORG=$1
    source $HOME/$REPO/non-remote-org/copy-tofrom-S3-orderer.sh $HOME $REPO $DATADIR $NEW_ORG
    copyEnvFromS3
    copyCertsFromS3
    sleep 5s
    source $HOME/$REPO/non-remote-org/create-channel-config.sh $HOME $REPO $DATADIR $NEW_ORG
    sleep 10s
    source $HOME/$REPO/non-remote-org/sign-channel-config.sh $HOME $REPO $NEW_ORG
    sleep 10s
    source $HOME/$REPO/non-remote-org/update-channel-config.sh $HOME $REPO $NEW_ORG
    sleep 10s

}


NEW_ORG=$1
SDIR=$(dirname "$0")
REPO=healthcare-hlf-k8
DATADIR=/opt/share/efs
#DATADIR=/opt/share
SCRIPTS=$DATADIR/scripts
mkdir -p $DATADIR/organizations/fabric-ca/$NEW_ORG

cat > ${DATADIR}/organizations/fabric-ca/$NEW_ORG/updateorg << EOF
${NEW_ORG}
EOF

main $NEW_ORG