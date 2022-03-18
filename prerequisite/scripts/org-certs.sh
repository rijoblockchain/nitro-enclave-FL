#!/bin/bash

set +e

#DOMAIN=$1
#ORG=$2
SDIR=$(dirname "$0")
source $SDIR/env.sh


sleep 2
mkdir -p organizations/peerOrganizations/$PEER_ORG.$DOMAIN

export FABRIC_CA_CLIENT_HOME=/organizations/peerOrganizations/$PEER_ORG.$DOMAIN

for ORG in $PEER_ORGS; do
  initOrgVars $ORG
  set -x
  fabric-ca-client enroll -u https://$CA_ADMIN_USER_PASS@$CA_NAME:7054 --caname $CA_NAME --tls.certfiles /organizations/fabric-ca/${ORG}RCA/tls-cert.pem
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/rca-'$ORG'-7054-rca-'$ORG'.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/rca-'$ORG'-7054-rca-'$ORG'.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/rca-'$ORG'-7054-rca-'$ORG'.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/rca-'$ORG'-7054-rca-'$ORG'.pem
    OrganizationalUnitIdentifier: orderer' > /organizations/peerOrganizations/$PEER_ORG.$DOMAIN/msp/config.yaml
done

for ORG in $PEER_ORGS; do
  initOrgVars $ORG
  COUNT=1
  while [[ "$COUNT" -le $NUM_PEERS ]]; do
    initPeerVars $ORG $COUNT
    log "##### Registering $PEER_NAME with $CA_NAME. Executing: fabric-ca-client register -d --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer"
    fabric-ca-client register --caname $CA_NAME --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer --tls.certfiles "/organizations/fabric-ca/${ORG}RCA/tls-cert.pem"
    
    
    if [ $COUNT -eq 1 ]; then
      echo "Register the $PEER_NAME admin"
      fabric-ca-client register --caname $CA_NAME --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.type admin --tls.certfiles /organizations/fabric-ca/${ORG}RCA/tls-cert.pem
      fabric-ca-client register --caname $CA_NAME --id.name $USER_NAME --id.secret $USER_PASS --id.type admin --tls.certfiles /organizations/fabric-ca/${ORG}RCA/tls-cert.pem
      CAHOST=$EXTERNALANCHORPEERHOSTNAME
    else
      CAHOST=$PEER_NAME.$DOMAIN
    fi

    echo "Generate the $PEER_NAME msp"
    set +x
    echo $CAHOST
    fabric-ca-client enroll -u https://$PEER_NAME_PASS@$CA_NAME:7054 --caname $CA_NAME -M "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/msp" --csr.hosts $CAHOST --csr.hosts  peer$COUNT-$ORG --tls.certfiles "/organizations/fabric-ca/${ORG}RCA/tls-cert.pem"

    cp "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/msp/config.yaml" "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/msp/config.yaml"

    echo "Generate the $PEER_NAME-tls certificates"
    set +x
    fabric-ca-client enroll -u https://$PEER_NAME_PASS@$CA_NAME:7054 --caname $CA_NAME -M "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/tls" --enrollment.profile tls --csr.hosts $CAHOST --csr.hosts  peer$COUNT-$ORG --csr.hosts $CA_NAME --csr.hosts localhost --tls.certfiles "/organizations/fabric-ca/${ORG}RCA/tls-cert.pem"
   
    cp "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/tls/tlscacerts/"* "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/tls/ca.crt"
    cp "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/tls/signcerts/"* "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/tls/server.crt"
    cp "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/tls/keystore/"* "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/tls/server.key"

    mkdir -p "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/msp/tlscacerts"
    cp "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/tls/tlscacerts/"* "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/msp/tlscacerts/ca.crt"

    mkdir -p "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/tlsca"
    cp "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/tls/tlscacerts/"* "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/tlsca/tlsca.$PEER_ORG.$DOMAIN-cert.pem"

    mkdir -p "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/rca"
    cp "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/peers/peer$COUNT-$ORG.$DOMAIN/msp/cacerts/"* "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/rca/rca.$PEER_ORG.$DOMAIN-cert.pem"


    COUNT=$((COUNT+1))
    done

    set +x
    fabric-ca-client enroll -u https://$USER_NAME:$USER_PASS@$CA_NAME:7054 --caname $CA_NAME -M "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/users/$USER_NAME@$PEER_ORG.$DOMAIN/msp" --tls.certfiles "/organizations/fabric-ca/${ORG}RCA/tls-cert.pem"
    { set +x; } 2>/dev/null
    cp "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/msp/config.yaml" "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/users/$USER_NAME@$PEER_ORG.$DOMAIN/msp/config.yaml"

    set +x
    fabric-ca-client enroll -u https://$ADMIN_NAME:$ADMIN_PASS@$CA_NAME:7054 --caname $CA_NAME -M "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/users/$ADMIN_NAME@$PEER_ORG.$DOMAIN/msp" --tls.certfiles "/organizations/fabric-ca/${ORG}RCA/tls-cert.pem"

    cp "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/msp/config.yaml" "/organizations/peerOrganizations/$PEER_ORG.$DOMAIN/users/$ADMIN_NAME@$PEER_ORG.$DOMAIN/msp/config.yaml"
    { set +x; } 2>/dev/null
done
