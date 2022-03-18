# Register identities

# Payer
export PATH=${PWD}/../bin:${PWD}:$PATH

export FABRIC_CFG_PATH=$PWD/../config/

export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/payer.hlf-network.com/

fabric-ca-client register --caname ca-payer --id.name owner --id.secret ownerpw --id.type client --tls.certfiles "${PWD}/organizations/fabric-ca/payer/tls-cert.pem"

fabric-ca-client enroll -u https://owner:ownerpw@localhost:7054 --caname ca-payer -M "${PWD}/organizations/peerOrganizations/payer.hlf-network.com/users/owner@payer.hlf-network.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/payer/tls-cert.pem"

cp "${PWD}/organizations/peerOrganizations/payer.hlf-network.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/payer.hlf-network.com/users/owner@payer.hlf-network.com/msp/config.yaml"

# Provider1

export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/provider1.hlf-network.com/

fabric-ca-client register --caname ca-provider1 --id.name owner --id.secret ownerpw --id.type client --tls.certfiles "${PWD}/organizations/fabric-ca/provider1/tls-cert.pem"

fabric-ca-client enroll -u https://owner:ownerpw@localhost:9054 --caname ca-provider1 -M "${PWD}/organizations/peerOrganizations/provider1.hlf-network.com/users/owner@provider1.hlf-network.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/provider1/tls-cert.pem"

cp "${PWD}/organizations/peerOrganizations/provider1.hlf-network.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/provider1.hlf-network.com/users/owner@provider1.hlf-network.com/msp/config.yaml"


# Provider2

export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/

fabric-ca-client register --caname ca-provider2 --id.name owner --id.secret ownerpw --id.type client --tls.certfiles "${PWD}/organizations/fabric-ca/provider2/tls-cert.pem"

fabric-ca-client enroll -u https://owner:ownerpw@localhost:11054 --caname ca-provider2 -M "${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/users/owner@provider2.hlf-network.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/provider2/tls-cert.pem"

cp "${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/users/owner@provider2.hlf-network.com/msp/config.yaml"

# Lab1

export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/lab1.hlf-network.com/

fabric-ca-client register --caname ca-lab1 --id.name owner --id.secret ownerpw --id.type client --tls.certfiles "${PWD}/organizations/fabric-ca/lab1/tls-cert.pem"

fabric-ca-client enroll -u https://owner:ownerpw@localhost:13054 --caname ca-lab1 -M "${PWD}/organizations/peerOrganizations/lab1.hlf-network.com/users/owner@lab1.hlf-network.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/lab1/tls-cert.pem"

cp "${PWD}/organizations/peerOrganizations/lab1.hlf-network.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/lab1.hlf-network.com/users/owner@lab1.hlf-network.com/msp/config.yaml"


# Pharma1

export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/pharma1.hlf-network.com/

fabric-ca-client register --caname ca-pharma1 --id.name owner --id.secret ownerpw --id.type client --tls.certfiles "${PWD}/organizations/fabric-ca/pharma1/tls-cert.pem"

fabric-ca-client enroll -u https://owner:ownerpw@localhost:15054 --caname ca-pharma1 -M "${PWD}/organizations/peerOrganizations/pharma1.hlf-network.com/users/owner@pharma1.hlf-network.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/pharma1/tls-cert.pem"

cp "${PWD}/organizations/peerOrganizations/pharma1.hlf-network.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/pharma1.hlf-network.com/users/owner@pharma1.hlf-network.com/msp/config.yaml"


# Create an asset in private data

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Provider1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/provider1.hlf-network.com/peers/peer0.provider1.hlf-network.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/provider1.hlf-network.com/users/owner@provider1.hlf-network.com/msp
export CORE_PEER_ADDRESS=localhost:9051
