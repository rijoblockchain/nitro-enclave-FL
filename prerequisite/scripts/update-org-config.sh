#!/usr/bin/env bash

source $(dirname "$0")/env.sh

function main {
    if [ $# -ne 2 ]; then
        echo "Usage: updateConfOrgFabric <admin-org possibly the first org in the network, where we carry out admin tasks>"
        exit 1
    fi
    local ADMINORG=$1
    local NEWORG=$2

    log "Updating channel config for Fabric in K8s"

    getDomain $ADMINORG

    # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st orderer
    IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
    initOrdererVars ${OORGS[0]} 1
    export ORDERER_PORT_ARGS="-o $ORDERER_HOST:$ORDERER_PORT --tls --cafile /organizations/ordererOrganizations/$DOMAIN/orderers/orderer1-${OORGS[0]}.$DOMAIN/msp/tlscacerts/tlsca.$DOMAIN-cert.pem"

    initPeerVars ${ADMINORG} 1
    switchToAdminIdentity ${ADMINORG}

    # Sign the config update
    updateConfigUpdate $NEWORG

    log "Congratulations! Config file has been updated on channel '$CHANNEL_NAME' by peer '$ADMINORG' admin for the new/deleted org $NEWORG"
    log "You can now start the new peer, then join the new peer to the channel"

}

function updateConfigUpdate {
   local NEWORG=$1
   log "Updating the configuration block of the channel '$CHANNEL_NAME' using config file /configtx/${NEWORG}/${NEWORG}_config_update_as_envelope.pb"
   peer channel update -f /configtx/${NEWORG}/${NEWORG}_config_update_as_envelope.pb -c $CHANNEL_NAME $ORDERER_PORT_ARGS
}



main $1 $2
