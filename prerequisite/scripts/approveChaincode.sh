

function main {
    orgsarr=($ORDERER_ORGS)
    ORDERER_ORG=${orgsarr[0]}
    getDomain $ORDERER_ORG
    COUNT=1
    PACKAGE_ID=$(printf "%s" $(awk -F'Chaincode code package identifier: ' '{print $2}' /opt/gopath/src/github.com/chaincode/basic/packaging/log.txt)) 

    peer lifecycle chaincode approveformyorg --channelID $CHANNEL_NAME --name basic --version 1.0 --init-required --package-id $PACKAGE_ID --sequence 1 -o orderer$COUNT-$ORDERER_ORG:7050 --tls --cafile /organizations/ordererOrganizations/$DOMAIN/orderers/orderer$COUNT-$ORDERER_ORG.$DOMAIN/msp/tlscacerts/tlsca.$DOMAIN-cert.pem
}


set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh


main
