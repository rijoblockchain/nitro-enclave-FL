#!/bin/bash

function main {
    orgsarr=($ORDERER_ORGS)
    ORDERER_ORG=${orgsarr[0]}
    getDomain $ORDERER_ORG
    COUNT=1
    peer channel create -o orderer1-$ORDERER_ORG:7050 -c $CHANNEL_NAME -f $CHANNEL_TX_FILE --outputBlock $CHANNEL_BLOCK_FILE --tls --cafile /organizations/ordererOrganizations/$DOMAIN/orderers/orderer$COUNT-$ORDERER_ORG.$DOMAIN/msp/tlscacerts/tlsca.$DOMAIN-cert.pem   
    
}


set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh $1 $2 $3

echo $ORDERER_ORGS $PEER_ORGS

main