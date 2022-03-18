

function main {
    orgsarr=($ORDERER_ORGS)
    ORDERER_ORG=${orgsarr[0]}
    getDomain $ORDERER_ORG
    COUNT=1
    
    peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name basic --version 1.0 --init-required --sequence 1 -o orderer$COUNT-$ORDERER_ORG:7050 --tls --cafile /organizations/ordererOrganizations/$DOMAIN/orderers/orderer$COUNT-$ORDERER_ORG.$DOMAIN/msp/tlscacerts/tlsca.$DOMAIN-cert.pem
}


set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh


main
