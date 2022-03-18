

function main {
    orgsarr=($ORDERER_ORGS)
    ORDERER_ORG=${orgsarr[0]}
    getDomain $ORDERER_ORG
    ORDERER_DOMAIN=$DOMAIN
    peerorgs=($PEER_ORGS)
    PEER_ORG=${peerorgs[0]}
    getDomain $PEER_ORG
    COUNT=1
    
    peer chaincode invoke -o orderer$COUNT-$ORDERER_ORG:7050 --isInit --tls true --cafile /organizations/ordererOrganizations/$ORDERER_DOMAIN/orderers/orderer$COUNT-$ORDERER_ORG.$ORDERER_DOMAIN/msp/tlscacerts/tlsca.$ORDERER_DOMAIN-cert.pem -C $CHANNEL_NAME -n basic --peerAddresses peer$COUNT-$PEER_ORG:7051 --tlsRootCertFiles /organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$PEER_ORG.$DOMAIN/tls/ca.crt -c '{"Args":["InitLedger"]}' --waitForEvent
}


set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh


main
