#!/bin/bash

set +e


SDIR=$(dirname "$0")
source $SDIR/env.sh 


sleep 2
mkdir -p organizations/ordererOrganizations/$DOMAIN

export FABRIC_CA_CLIENT_HOME=/organizations/ordererOrganizations/$DOMAIN

for ORG in $ORDERER_ORGS; do
  initOrgVars $ORG
  set -x
  fabric-ca-client enroll -u https://$CA_ADMIN_USER_PASS@$CA_NAME:10054 --caname $CA_NAME --tls.certfiles /organizations/fabric-ca/${ORG}RCA/tls-cert.pem
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/rca-'$ORG'-10054-rca-'$ORG'.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/rca-'$ORG'-10054-rca-'$ORG'.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/rca-'$ORG'-10054-rca-'$ORG'.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/rca-'$ORG'-10054-rca-'$ORG'.pem
    OrganizationalUnitIdentifier: orderer' > /organizations/ordererOrganizations/$DOMAIN/msp/config.yaml
done


for ORG in $ORDERER_ORGS; do
  initOrgVars $ORG
  COUNT=1
  COUNTER=-1
 
  while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
    initOrdererVars $ORG $COUNT
    ordererarr=($EXTERNAL_ORDERER_ADDRESSES)
    if [ $COUNT -gt 1 ]; then
      IFS=':' read -a arr <<< "${ordererarr[$COUNTER]}"
      CAHOST=${arr[0]}
    else
      CAHOST=$ORDERER_NAME.$DOMAIN
    fi
    log "Registering $ORDERER_NAME with $CA_NAME"
    set +x
    fabric-ca-client register --caname $CA_NAME --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer --tls.certfiles /organizations/fabric-ca/${ORG}RCA/tls-cert.pem
    { set +x; } 2>/dev/null
    
    if [ $COUNT -eq 1 ]; then
      echo "Register the $ORDERER_NAME admin"
      fabric-ca-client register --caname $CA_NAME --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.type admin --tls.certfiles /organizations/fabric-ca/${ORG}RCA/tls-cert.pem
      mkdir -p organizations/ordererOrganizations/$DOMAIN/orderers
      mkdir -p organizations/ordererOrganizations/$DOMAIN/users
      mkdir -p organizations/ordererOrganizations/$DOMAIN/users/Admin@$DOMAIN
    fi

    mkdir -p organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN
    echo $CAHOST
    echo "Generate the $ORDERER_NAME msp"
    fabric-ca-client enroll -u https://$ORDERER_NAME_PASS@$CA_NAME:10054 --caname $CA_NAME -M /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/msp --csr.hosts $CAHOST --csr.hosts localhost --csr.hosts $CA_NAME --csr.hosts $ORDERER_NAME --tls.certfiles /organizations/fabric-ca/${ORG}RCA/tls-cert.pem
    
    cp /organizations/ordererOrganizations/$DOMAIN/msp/config.yaml /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/msp/config.yaml
    
    echo "Generate the $ORDERER_NAME-tls certificates"
    fabric-ca-client enroll -u https://$ORDERER_NAME_PASS@$CA_NAME:10054 --caname $CA_NAME -M /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/tls --enrollment.profile tls --csr.hosts $CAHOST --csr.hosts localhost --csr.hosts $CA_NAME --csr.hosts $ORDERER_NAME --tls.certfiles /organizations/fabric-ca/${ORG}RCA/tls-cert.pem
    
    cp /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/tls/tlscacerts/* /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/tls/ca.crt
    cp /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/tls/signcerts/* /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/tls/server.crt
    cp /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/tls/keystore/* /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/tls/server.key

    mkdir -p /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/msp/tlscacerts
    cp /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/tls/tlscacerts/* /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/msp/tlscacerts/tlsca.$DOMAIN-cert.pem

    mkdir -p /organizations/ordererOrganizations/$DOMAIN/msp/tlscacerts
    cp /organizations/ordererOrganizations/$DOMAIN/orderers/$ORDERER_NAME.$DOMAIN/tls/tlscacerts/* /organizations/ordererOrganizations/$DOMAIN/msp/tlscacerts/tlsca.$DOMAIN-cert.pem

    COUNT=$((COUNT+1))
    COUNTER=$((COUNTER+2))
  done


  echo "Generate the admin msp"
  set -x
  fabric-ca-client enroll -u https://$ADMIN_NAME:$ADMIN_PASS@$CA_NAME:10054 --caname $CA_NAME -M /organizations/ordererOrganizations/$DOMAIN/users/Admin@$DOMAIN/msp --tls.certfiles /organizations/fabric-ca/${ORG}RCA/tls-cert.pem
  { set +x; } 2>/dev/null
  
  cp /organizations/ordererOrganizations/$DOMAIN/msp/config.yaml /organizations/ordererOrganizations/$DOMAIN/users/Admin@$DOMAIN/msp/config.yaml

done









