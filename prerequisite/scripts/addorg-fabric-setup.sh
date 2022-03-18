#!/bin/bash



set -e

NEW_ORG=$2

SDIR=$(dirname "$0")
source $SDIR/${NEW_ORG}env.sh
NEW_ORG_MSP_DIR=$DATADIR/organizations/fabric-ca/$NEW_ORG/msp



function main {
    PEERORG=$1
    NEW_ORG=$2
    file=/organizations/fabric-ca/$NEW_ORG/updateorg
    if [ -f "$file" ]; then
       NEW_ORG=$(cat $file)
       echo "File '$file' exists - peer '$PEERORG' admin creating a new org '$NEW_ORG'"
       mkdir -p /configtx/$NEW_ORG
       genConfigForNewOrg

       log "Generating the channel config for new org '$NEW_ORG'"

       # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st orderer
       IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
       initOrdererVars ${OORGS[0]} 1
       getDomain ${OORGS[0]}
       export ORDERER_PORT_ARGS="-o $ORDERER_HOST:$ORDERER_PORT --tls --cafile /organizations/ordererOrganizations/$DOMAIN/orderers/orderer1-${OORGS[0]}.$DOMAIN/msp/tlscacerts/tlsca.$DOMAIN-cert.pem"

       initPeerVars ${PEERORG} 1

       generateNewOrgConfig

       # Fetch config block
       fetchConfigBlock
       source /scripts/${NEW_ORG}env.sh

       # Create config update envelope with CRL and update the config block of the channel
       log "About to start createConfigUpdate"
       createConfigUpdate
       if [ $? -eq 1 ]; then
           log "Org '$NEW_ORG' already exists in the channel config. Config will not be updated or signed"
           exit 0
       else
           log "Congratulations! The config file for the new org '$NEW_ORG' was successfully added by peer '$PEERORG' admin. Now it must be signed by all org admins"
           log "After this pod completes, run the pod which contains the script addorg-fabric-sign.sh"
           exit 0
       fi
    else
        log "File '$file' does not exist - no new org will be created - exiting"
        exit 1
    fi
}


function genConfigForNewOrg {
   
   log "generating config.yaml for new org"
   {
       echo "
################################################################################
#
#   Section: Organizations
#
################################################################################
Organizations:"
      initPeerVars $NEW_ORG 1
      printOrg
      echo "
    AnchorPeers:
       - Host: $EXTERNALANCHORPEERHOSTNAME
         Port: 7051"
   } > /configtx/$NEW_ORG/configtx.yaml
   
   
}

# printOrg
function printOrg {
   echo "
  - &$ORG_CONTAINER_NAME

    Name: $ORG

    # ID to load the MSP definition as
    ID: $ORG_MSP_ID

    # MSPDir is the filesystem path which contains the MSP configuration
    MSPDir: $NEW_ORG_MSP_DIR

    Policies: 
        Readers:
            Type: Signature
            Rule: \"OR(\'$ORG_MSP_ID.member\')\"
        Writers:
            Type: Signature
            Rule: \"OR(\'$ORG_MSP_ID.member\')\"
        Admins:
            Type: Signature
            Rule: \"OR(\'$ORG_MSP_ID.admin\')\"
        Endorsement:
            Type: Signature
            Rule: \"OR(\'$ORG_MSP_ID.peer\')\""

    
}


function generateNewOrgConfig() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    fatal "configtxgen tool not found. exiting"
  fi

  log "Printing the new Org configuration for '$NEW_ORG' at '/configtx'"
  export FABRIC_CFG_PATH=/configtx/$NEW_ORG
  cd $FABRIC_CFG_PATH
  configtxgen -printOrg $NEW_ORG > /tmp/$NEW_ORG.json
  cp /tmp/$NEW_ORG.json /configtx/$NEW_ORG
}

function fetchConfigBlock {
   
   source /scripts/env.sh
   switchToAdminIdentity $PEERORG
   export FABRIC_CFG_PATH=/configtx
   log "Fetching the configuration block into '$CONFIG_BLOCK_FILE' of the channel '$CHANNEL_NAME'"
   log "peer channel fetch config '$CONFIG_BLOCK_FILE' -c '$CHANNEL_NAME' '$ORDERER_PORT_ARGS'"
   peer channel fetch config $CONFIG_BLOCK_FILE -c $CHANNEL_NAME $ORDERER_PORT_ARGS
   log "fetched config block"
}

function isOrgInChannelConfig {
    if [ $# -ne 1 ]; then
        log "Usage: isOrgInChannelConfig <Config JSON file>"
        exit 1
    fi
    log "Checking whether org '$NEW_ORG' exists in the channel config"
    local JSONFILE=$1

    # check if the org exists in the channel config
    log "About to execute jq '.channel_group.groups.Application.groups | contains({$NEW_ORG})'"
    if cat ${JSONFILE} | jq -e ".channel_group.groups.Application.groups | contains({$NEW_ORG})" > /dev/null; then
        log "Org '$NEW_ORG' exists in the channel config"
        echo "true"
    else
        log "Org '$NEW_ORG' does not exist in the channel config"
        echo "false"
    fi
}

function createConfigUpdate {
    initPeerVars $NEW_ORG 1

    log "Creating config update payload for the new organization '$NEW_ORG'"
    #make a copy of the .json files below
    jsonbkdir=/configtx/${NEW_ORG}  

    # Convert the config block protobuf to JSON and Extract the config from the config block
    configtxlator proto_decode --input $CONFIG_BLOCK_FILE --type common.Block | jq .data.data[0].payload.data.config > /tmp/${NEW_ORG}_config.json
    cp /tmp/${NEW_ORG}_config.json $jsonbkdir

    var="$(isOrgInChannelConfig /tmp/${NEW_ORG}_config.json)"
    
    if [[ "${var}" == "true" ]]; then
        log "Org '$NEW_ORG' already exists in the channel config. Config will not be updated. Exiting createConfigUpdate"
        return 1
    fi

    NEW_ORG_MSP=${NEW_ORG}MSP
    # Append the new org configuration information
    jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"'"${NEW_ORG_MSP}"'":.[1]}}}}}' /tmp/${NEW_ORG}_config.json /configtx/$NEW_ORG/$NEW_ORG.json > /tmp/${NEW_ORG}_modified_config.json
    
    # Append the anchor peer configuration information
    PEER_HOST=$EXTERNALANCHORPEERHOSTNAME
    jq '.channel_group.groups.Application.groups.'"${NEW_ORG_MSP}"'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'"${PEER_HOST}"'","port": 7051}]},"version": "0"}}' /tmp/${NEW_ORG}_modified_config.json > /tmp/${NEW_ORG}_updated_config.json

    # copy the block config to the /data directory in case we need to update it with another config change later
    cp /tmp/${NEW_ORG}_updated_config.json $jsonbkdir

    

    # Create the config diff protobuf
    configtxlator proto_encode --input /tmp/${NEW_ORG}_config.json --type common.Config --output /tmp/${NEW_ORG}_config.pb
    configtxlator proto_encode --input /tmp/${NEW_ORG}_updated_config.json --type common.Config --output /tmp/${NEW_ORG}_updated_config.pb
    configtxlator compute_update --channel_id $CHANNEL_NAME --original /tmp/${NEW_ORG}_config.pb --updated /tmp/${NEW_ORG}_updated_config.pb --output /tmp/${NEW_ORG}_config_update.pb


    # Convert the config diff protobuf to JSON
    configtxlator proto_decode --input /tmp/${NEW_ORG}_config_update.pb --type common.ConfigUpdate | jq . > /tmp/${NEW_ORG}_config_update.json
    cp /tmp/${NEW_ORG}_config_update.json $jsonbkdir

    # Create envelope protobuf container config diff to be used in the "peer channel update" command to update the channel configuration block
    echo '{"payload":{"header":{"channel_header":{"channel_id":"'"${CHANNEL_NAME}"'", "type":2}},"data":{"config_update":'$(cat /tmp/${NEW_ORG}_config_update.json)'}}}' | jq . > /tmp/${NEW_ORG}_config_update_as_envelope.json
    configtxlator proto_encode --input /tmp/${NEW_ORG}_config_update_as_envelope.json --type common.Envelope --output /tmp/${NEW_ORG}_config_update_as_envelope.pb

    # copy to the /organizations/fabric-ca/${NEW_ORG}RCA directory so the file can be signed by other admins
    cp /tmp/${NEW_ORG}_config_update_as_envelope.pb /organizations/fabric-ca/${NEW_ORG}
    cp /tmp/${NEW_ORG}_config_update_as_envelope.pb $jsonbkdir
    cp /tmp/${NEW_ORG}_config_update_as_envelope.json $jsonbkdir

    log "Created config update payload for the new organization '$NEW_ORG', in file /organizations/fabric-ca/${NEW_ORG}/${NEW_ORG}_config_update_as_envelope.pb"


#    # Start the configtxlator
#    configtxlator start &
#    configtxlator_pid=$!
#    log "configtxlator_pid:$configtxlator_pid"
#    log "Sleeping 5 seconds for configtxlator to start..."
#    sleep 5

#    pushd /tmp

#    #make a copy of the .json files below
#    jsonbkdir=/configtx/addorg-${NEW_ORG}-`date +%Y%m%d-%H%M`
#    mkdir $jsonbkdir

#    CTLURL=http://127.0.0.1:7059
#    # Convert the config block protobuf to JSON
#    curl -X POST --data-binary @$CONFIG_BLOCK_FILE $CTLURL/protolator/decode/common.Block > ${NEW_ORG}_config_block.json
#    # Extract the config from the config block
#    jq .data.data[0].payload.data.config ${NEW_ORG}_config_block.json > ${NEW_ORG}_config.json
#    sudo cp ${NEW_ORG}_config_block.json $jsonbkdir
#    sudo cp ${NEW_ORG}_config.json $jsonbkdir

#    isOrgInChannelConfig ${NEW_ORG}_config.json
#    if [ $? -eq 0 ]; then
#         log "Org '$NEW_ORG' already exists in the channel config. Config will not be updated. Exiting createConfigUpdate"
#         return 1
#    fi

#    # Append the new org configuration information
#    jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"'$NEW_ORG'":.[1]}}}}}' ${NEW_ORG}_config.json ${NEW_ORG}.json > ${NEW_ORG}_updated_config.json
#    # copy the block config to the /data directory in case we need to update it with another config change later
#    cp /tmp/${NEW_ORG}_updated_config.json $jsonbkdir

#    # Create the config diff protobuf
#    curl -X POST --data-binary @${NEW_ORG}_config.json $CTLURL/protolator/encode/common.Config > ${NEW_ORG}_config.pb
#    curl -X POST --data-binary @${NEW_ORG}_updated_config.json $CTLURL/protolator/encode/common.Config > ${NEW_ORG}_updated_config.pb
#    curl -X POST -F original=@${NEW_ORG}_config.pb -F updated=@${NEW_ORG}_updated_config.pb $CTLURL/configtxlator/compute/update-from-configs -F channel=$CHANNEL_NAME > ${NEW_ORG}_config_update.pb

#    # Convert the config diff protobuf to JSON
#    curl -X POST --data-binary @${NEW_ORG}_config_update.pb $CTLURL/protolator/decode/common.ConfigUpdate > ${NEW_ORG}_config_update.json
#    cp /tmp/${NEW_ORG}_config_update.json $jsonbkdir

#    # Create envelope protobuf container config diff to be used in the "peer channel update" command to update the channel configuration block
#    echo '{"payload":{"header":{"channel_header":{"channel_id":"'"${CHANNEL_NAME}"'", "type":2}},"data":{"config_update":'$(cat ${NEW_ORG}_config_update.json)'}}}' > ${NEW_ORG}_config_update_as_envelope.json
#    curl -X POST --data-binary @${NEW_ORG}_config_update_as_envelope.json $CTLURL/protolator/encode/common.Envelope > /tmp/${NEW_ORG}_config_update_as_envelope.pb
#    # copy to the /data directory so the file can be signed by other admins
#    cp /tmp/${NEW_ORG}_config_update_as_envelope.pb /organizations/fabric-ca/${NEW_ORG}RCA
#    cp /tmp/${NEW_ORG}_config_update_as_envelope.pb $jsonbkdir
#    cp /tmp/${NEW_ORG}_config_update_as_envelope.json $jsonbkdir
#    ls -lt $jsonbkdir

#    # Stop configtxlator
#    kill $configtxlator_pid
#    log "Created config update payload for the new organization '$NEW_ORG', in file //organizations/fabric-ca/${NEW_ORG}RCA/${NEW_ORG}_config_update_as_envelope.pb"

#    popd
#    return 0
}


main $1 $2