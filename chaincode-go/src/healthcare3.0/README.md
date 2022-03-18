docker rmi -f $(docker images -a -q)

cd ~/healthcare-blockchain-FL/chaincode-go/src/healthcare3.0


go mod init healthcare3.0
go build main.go

cd ~/healthcare-blockchain-FL/hlf-network

./network.sh up createChannel -ca -s couchdb


./network.sh deployCC -ccn healthcare -ccp ../chaincode-go/src/healthcare3.0/ -ccl go -ccep "OR('PayerMSP.peer')" -cccg ../chaincode-go/src/healthcare3.0/collections_config.json


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

fabric-ca-client register --caname ca-provider2 --id.name read --id.secret readpw --id.type client --tls.certfiles "${PWD}/organizations/fabric-ca/provider2/tls-cert.pem"

fabric-ca-client enroll -u https://read:readpw@localhost:11054 --caname ca-provider2 -M "${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/users/read@provider2.hlf-network.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/provider2/tls-cert.pem"

cp "${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/users/read@provider2.hlf-network.com/msp/config.yaml"



------------------------------------------------------------------------------------



# . scripts/envVar.sh

# peer lifecycle chaincode package private.tar.gz -p ../chaincode-go/src/hlf2-0 --label=private.1-0 -l golang


## Install in Payer


peer lifecycle chaincode install private.tar.gz --tls --cafile $ORDERER_CA --peerAddresses peer0.payer.hlf-network.com:7051 --tlsRootCertFiles $PEER0_PAYER_CA



## Install in Provider1

setGlobals 2
setGlobalsCLI 2

PEER0_PROVIDER1_CA=${PWD}/organizations/peerOrganizations/provider1.hlf-network.com/peers/peer0.provider1.hlf-network.com/tls/ca.crt

peer lifecycle chaincode install private.tar.gz --tls --cafile $ORDERER_CA --peerAddresses localhost:9051 --tlsRootCertFiles $PEER0_PROVIDER1_CA


## Install in Provider2

setGlobals 3
setGlobalsCLI 3

PEER0_PROVIDER2_CA=${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/peers/peer0.provider2.hlf-network.com/tls/ca.crt

peer lifecycle chaincode install private.tar.gz --tls --cafile $ORDERER_CA --peerAddresses localhost:11051 --tlsRootCertFiles $PEER0_PROVIDER2_CA


# ApproveForMyOrg Payer

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/hlf-network.com/orderers/orderer.hlf-network.com/msp/tlscacerts/tlsca.hlf-network.com-cert.pem
export PEER0_PAYER_CA=${PWD}/organizations/peerOrganizations/payer.hlf-network.com/peers/peer0.payer.hlf-network.com/tls/ca.crt
export PEER0_PROVIDER1_CA=${PWD}/organizations/peerOrganizations/provider1.hlf-network.com/peers/peer0.provider1.hlf-network.com/tls/ca.crt
export PEER0_PROVIDER2_CA=${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/peers/peer0.provider2.hlf-network.com/tls/ca.crt
export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/hlf-network.com/orderers/orderer.hlf-network.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/hlf-network.com/orderers/orderer.hlf-network.com/tls/server.key
export PACKAGE=private_1.0:320f4938cb9739976add082a0f8ecc045201689add86bb088d986079cf6a6ad8

export CORE_PEER_LOCALMSPID="PayerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_PAYER_CA
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/payer.hlf-network.com/users/Admin@payer.hlf-network.com/msp
export CORE_PEER_ADDRESS=localhost:7051


peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.hlf-network.com --channelID mychannel --name private --version 1.0 --collections-config ../chaincode-go/src/hlf2-0/collections_config.json --package-id $PACKAGE --sequence 1 --peerAddresses=localhost:7051 --tls true --cafile $ORDERER_CA --tlsRootCertFiles $PEER0_PAYER_CA --signature-policy "OR ('PayorMSP.peer')"

# queryApproved Payer

peer lifecycle chaincode queryapproved -C mychannel -n private --sequence 1 --peerAddresses=localhost:7051 --tls --cafile $ORDERER_CA --tlsRootCertFiles $PEER0_PAYER_CA

# checkcommitreadiness


peer lifecycle chaincode checkcommitreadiness -o orderer.example.com:7050 --channelID mychannel --tls --cafile $ORDERER_CA --name private --version 1.0  --sequence 1 --peerAddresses=localhost:7051 --tls true --cafile $ORDERER_CA --tlsRootCertFiles $PEER0_PAYER_CA --signature-policy "AND ('PayorMSP.peer')" --collections-config ../chaincode-go/src/hlf2-0/collections_config.json



# ApproveForMyOrg Provider1

export CORE_PEER_LOCALMSPID="Provider1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_PROVIDER1_CA
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/provider1.hlf-network.com/users/Admin@provider1.hlf-network.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.hlf-network.com --channelID mychannel --name private --version 1.0 --collections-config ../chaincode-go/src/hlf2-0/collections_config.json --package-id $PACKAGE --sequence 1 --peerAddresses=localhost:9051 --tls true --cafile $ORDERER_CA --tlsRootCertFiles $PEER0_PROVIDER1_CA --signature-policy "OR ('PayorMSP.peer')"

# queryApproved Payer

peer lifecycle chaincode queryapproved -C mychannel -n private --sequence 1 --peerAddresses=localhost:9051 --tls --cafile $ORDERER_CA --tlsRootCertFiles $PEER0_PROVIDER1_CA

# checkcommitreadiness


peer lifecycle chaincode checkcommitreadiness -o orderer.example.com:7050 --channelID mychannel --tls --cafile $ORDERER_CA --name private --version 1.0  --sequence 1  --peerAddresses=localhost:9051 --tls true --cafile $ORDERER_CA --tlsRootCertFiles $PEER0_PROVIDER1_CA --signature-policy "OR ('PayorMSP.peer')" --collections-config ../chaincode-go/src/hlf2-0/collections_config.json



# ApproveForMyOrg Provider2

export CORE_PEER_LOCALMSPID="Provider2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_PROVIDER2_CA
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/users/Admin@provider2.hlf-network.com/msp
export CORE_PEER_ADDRESS=localhost:11051

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.hlf-network.com --channelID mychannel --name private --version 1.0 --collections-config ../chaincode-go/src/hlf2-0/collections_config.json --package-id $PACKAGE --sequence 1 --peerAddresses=localhost:11051 --tls true --cafile $ORDERER_CA --tlsRootCertFiles $PEER0_PROVIDER2_CA --signature-policy "OR ('PayorMSP.peer')"

# queryApproved Payer

peer lifecycle chaincode queryapproved -C mychannel -n private --sequence 1 --peerAddresses=localhost:11051 --tls --cafile $ORDERER_CA --tlsRootCertFiles $PEER0_PROVIDER2_CA

# checkcommitreadiness


peer lifecycle chaincode checkcommitreadiness -o orderer.example.com:7050 --channelID mychannel --tls --cafile $ORDERER_CA --name private --version 1.0  --sequence 1  --peerAddresses=localhost:11051 --tlsRootCertFiles $PEER0_PROVIDER2_CA --signature-policy "OR ('PayorMSP.peer')" --collections-config ../chaincode-go/src/hlf2-0/collections_config.json


# Commit

export CORE_PEER_LOCALMSPID="PayerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_PAYER_CA
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/payer.hlf-network.com/users/Admin@payer.hlf-network.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.hlf-network.com --channelID mychannel --name private --version 1.0 --sequence 1 --collections-config ../chaincode-go/src/hlf2-0/collections_config.json --signature-policy "OR ('PayorMSP.peer')" --tls --cafile $ORDERER_CA --peerAddresses localhost:7051 --tlsRootCertFiles $PEER0_PAYER_CA  --waitForEvent


peer lifecycle chaincode querycommitted --channelID mychannel --name private

