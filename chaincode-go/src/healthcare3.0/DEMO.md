# Payer Terminal - Setting the env variables

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true

export CORE_PEER_LOCALMSPID="PayerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/payer.hlf-network.com/peers/peer0.payer.hlf-network.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/payer.hlf-network.com/users/owner@payer.hlf-network.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# Provider1 Terminal - Setting the env variables

cd hlf-network

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true

export CORE_PEER_LOCALMSPID="Provider1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/provider1.hlf-network.com/peers/peer0.provider1.hlf-network.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/provider1.hlf-network.com/users/owner@provider1.hlf-network.com/msp
export CORE_PEER_ADDRESS=localhost:9051


# Provider2 Terminal

cd hlf-network

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true

export CORE_PEER_LOCALMSPID="Provider2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/peers/peer0.provider2.hlf-network.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/provider2.hlf-network.com/users/owner@provider2.hlf-network.com/msp
export CORE_PEER_ADDRESS=localhost:11051

# Lab1 Terminal

cd hlf-network

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true

export CORE_PEER_LOCALMSPID="Lab1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/lab1.hlf-network.com/peers/peer0.lab1.hlf-network.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/lab1.hlf-network.com/users/owner@lab1.hlf-network.com/msp
export CORE_PEER_ADDRESS=localhost:13051

# Pharma1 Terminal

cd hlf-network

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true

export CORE_PEER_LOCALMSPID="Pharma1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/pharma1.hlf-network.com/peers/peer0.pharma1.hlf-network.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/pharma1.hlf-network.com/users/owner@pharma1.hlf-network.com/msp
export CORE_PEER_ADDRESS=localhost:15051

# Payer Terminal - Patient1 goes to Payer and Payer creates the patient

export GLOBAL_MODEL=$(echo -n "{\"docType\":\"globalModel\",\"globalModelID\":\"gm123\",\"IPFSHash\":\"QmaeeW46ADnnU9ZteBMnJ4UjYRZMZtfv8gukDq32pLnLuY\"}" | base64 | tr -d \\n)

peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.hlf-network.com --tls --cafile "${PWD}/organizations/ordererOrganizations/hlf-network.com/orderers/orderer.hlf-network.com/msp/tlscacerts/tlsca.hlf-network.com-cert.pem" -C healthcarechannel -n healthcare --peerAddresses localhost:7051  --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/payer.hlf-network.com/peers/peer0.payer.hlf-network.com/tls/ca.crt"  -c '{"function":"SaveGlobalModel","Args":[]}' --transient "{\"global_model\":\"$GLOBAL_MODEL\"}"

peer chaincode query -C healthcarechannel -n healthcare -c '{"function":"ReadGlobalModelHash","Args":["gm123"]}'

peer chaincode query -C healthcarechannel -n healthcare -c '{"function":"ReadGlobalModelHash","Args":["gm123"]}' | jq . > iss.json

 jq .IPFSHash iss.json 

 export GLOBAL_WEIGHTS=$(echo -n "{\"docType\":\"globalWeights\",\"globalWeightsID\":\"gw123\",\"encryptedGlobalWeights\":\"QmaeeW46ADnnU9ZteBMnJ4UjYRZMZtfv8gukDq32pLnLuY\"}" | base64 | tr -d \\n)

 peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.hlf-network.com --tls --cafile "${PWD}/organizations/ordererOrganizations/hlf-network.com/orderers/orderer.hlf-network.com/msp/tlscacerts/tlsca.hlf-network.com-cert.pem" -C healthcarechannel -n healthcare --peerAddresses localhost:7051  --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/payer.hlf-network.com/peers/peer0.payer.hlf-network.com/tls/ca.crt"  -c '{"function":"SaveGlobalWeights","Args":[]}' --transient "{\"global_weights\":\"$GLOBAL_WEIGHTS\"}"

 peer chaincode query -C healthcarechannel -n healthcare -c '{"function":"ReadGlobalWeightsInfo","Args":["gw123"]}'

