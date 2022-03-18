#!/bin/bash

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp {
    local PP=$(one_line_pem $4)
    local CP=$(one_line_pem $5)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${CAPORT}/$3/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template.json
}

function yaml_ccp {
    local PP=$(one_line_pem $4)
    local CP=$(one_line_pem $5)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${CAPORT}/$3/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}

ORG=1
P0PORT=9051
CAPORT=9054
PEERPEM=organizations/peerOrganizations/provider1.hlf-network.com/tlsca/tlsca.provider1.hlf-network.com-cert.pem
CAPEM=organizations/peerOrganizations/provider1.hlf-network.com/ca/ca.provider1.hlf-network.com-cert.pem

echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/provider1.hlf-network.com/connection-provider1.json
echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/provider1.hlf-network.com/connection-provider1.yaml

ORG=2
P0PORT=11051
CAPORT=11054
PEERPEM=organizations/peerOrganizations/provider2.hlf-network.com/tlsca/tlsca.provider2.hlf-network.com-cert.pem
CAPEM=organizations/peerOrganizations/provider2.hlf-network.com/ca/ca.provider2.hlf-network.com-cert.pem

echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/provider2.hlf-network.com/connection-provider2.json
echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/provider2.hlf-network.com/connection-provider2.yaml
