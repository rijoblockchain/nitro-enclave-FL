set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh

for ORG in $PEER_ORGS; do
    initOrgVars $ORG
    orgsarr=($ORDERER_ORGS)
    ORDERER_ORG=${orgsarr[0]}
    getDomain $ORDERER_ORG
    COUNT=1
    peer channel update -o orderer$COUNT-$ORDERER_ORG:7050  -c $CHANNEL_NAME -f $ANCHOR_TX_FILE --tls --cafile /organizations/ordererOrganizations/$DOMAIN/orderers/orderer$COUNT-$ORDERER_ORG.$DOMAIN/msp/tlscacerts/tlsca.$DOMAIN-cert.pem
done 