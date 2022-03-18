#!/usr/bin/env bash

source $(dirname "$0")/env.sh

function main {
    if [ $# -ne 2 ]; then
        echo "Usage: signConfOrgFabric <home-dir> <repo-name> <signing-org - the org signing the config> <new-org - an org if we are adding a new org, otherwise leave blank>"
        exit 1
    fi
    
    local SIGNINGORG=$1
    local NEWORG=$2

    log "Signing org config for Fabric in K8s. Signer is: '$SIGNINGORG'. New org being added to config is: '$NEWORG'"

    #config update can't be signed and updated by the new org, if we are adding one
    if [[ "$SIGNINGORG" == "$NEWORG" ]]; then
        log "Error: signing org == new org being added. '$NEWORG' is being added to the network. It cannot sign the config update. Signer is: '$SIGNINGORG'"
        break
    fi

    log "Signing the config for the new org '$NEWORG'"

    # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st orderer
    IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
    initOrdererVars ${OORGS[0]} 1
    export ORDERER_PORT_ARGS="-o $ORDERER_HOST:$ORDERER_PORT --tls --cafile /organizations/ordererOrganizations/$DOMAIN/orderers/orderer1-${OORGS[0]}.$DOMAIN/msp/tlscacerts/tlsca.$DOMAIN-cert.pem"

    initPeerVars ${SIGNINGORG} 1
    switchToAdminIdentity ${SIGNINGORG}

    # Sign the config update
    signConfigUpdate $NEWORG

    log "Congratulations! The config file has been signed by peer '$SIGNINGORG' admin for the new/deleted org '$NEWORG'"
    

}

function signConfigUpdate {
   local NEWORG=$1
   log "Signing the configuration block of the channel '$CHANNEL_NAME' in config file /configtx/${NEWORG}/${NEWORG}_config_update_as_envelope.pb"
   peer channel signconfigtx -f /configtx/${NEWORG}/${NEWORG}_config_update_as_envelope.pb
}

main $1 $2
