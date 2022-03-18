#!/usr/bin/env bash


SDIR=$(dirname "$0")
DATA=/opt/share/efs
#DATA=/opt/share
SCRIPTS=$DATA/scripts
source $SCRIPTS/env.sh
REPO=healthcare-hlf-k8
source $HOME/$REPO/fabric-main/utilities.sh
K8STEMPLATES=k8s-templates
K8SYAML=k8s
FABRICORGS=""

rcaport=30100
icaport=30200
ordererport=30300
peerport=30400

function genFabricOrgs {
    log "Generating list of Fabric Orgs"
    for ORG in $ORGS; do
        getDomain $ORG
        FABRICORGS+=$ORG
        FABRICORGS+="."
        FABRICORGS+=$DOMAIN
        FABRICORGS+=" "
    done
    log "Fabric Orgs are $FABRICORGS"
}

function genNamespaces {
    log "Generating K8s namespace YAML files"
    cd $HOME/$REPO
    #sed -e "s/%DOMAIN%/$1/g" ${K8STEMPLATES}/fabric-namespace.yaml > ${K8SYAML}/fabric-namespace-$1.yaml
    for ORG in $PEER_ORGS; do
        sed -e "s/%DOMAIN%/${ORG}/g" ${K8STEMPLATES}/fabric-namespace.yaml > ${K8SYAML}/fabric-namespace-$ORG.yaml
    done
}

function genPVC {
    log "Generating K8s PVC YAML files"
    cd $HOME/$REPO
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        sed -e "s/%EFSSERVER%/${EFSSERVER}/g" ${K8STEMPLATES}/fabric-pvc.yaml > ${K8SYAML}/fabric-pvc-$ORG.yaml
    done
    
}

function genRCA {
    log "Generating RCA K8s YAML files"
    if [ -f $SCRIPTS/rca-ports.sh ]; then
        log "Loading the ports used by RCAs"
        source $SCRIPTS/rca-ports.sh
        for portValue in "${RCA_PORTS_IN_USE[@]}"
        do
          if [[ portValue -gt rcaport ]]; then
            rcaport=$((portValue+0))
          fi
        done
        rcaport=$((rcaport+5))
    fi
    log "The starting RCA port is: ${rcaport}"
    for ORG in $ORGS; do
        getDomain $ORG
        # Check if the RCA already has a port assigned
        local portAssigned=false
        for key in ${!RCA_PORTS_IN_USE[@]}
        do
            if [ "${key}" == "rca-$ORG" ] ; then
                log "RCA ${key} already has port assigned: ${RCA_PORTS_IN_USE[${key}]} "
                portAssigned=true
                break
            fi
        done
        if [ "$portAssigned" = true ] ; then
            continue
        fi
        # Find a port number that hasn't been used
        while true
        do
            local portInUse=false
            for key in ${!RCA_PORTS_IN_USE[@]}
            do
                if [ "${RCA_PORTS_IN_USE[${key}]}" -eq "$rcaport" ] ; then
                    rcaport=$((rcaport+5))
                    portInUse=true
                    break
                fi
            done
            if [ "$portInUse" = false ] ; then
                break
            fi
        done
        
        log "Port assigned to rca: rca-$ORG is $rcaport"
        for ORG in $ORDERER_ORGS; do
            RCA_PORTS_IN_USE+=( ["rca-$ORG"]=$rcaport )
            initOrgVars $ORG
            getDomain $ORG
            port=10054
            sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" $DATA/organizations/fabric-ca/rca/fabric-ca-server-config.yaml > $DATA/organizations/fabric-ca/${ORG}RCA/fabric-ca-server-config.yaml
            sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%PORT%/${port}/g" -e "s/%NODEPORT%/${rcaport}/g" -e "s/%FABRIC_TAG%/${FABRIC_TAG}/g" -e "s/%RCA%/${ORG}/g" -e "s/%CA_ADMIN_USER_PASS%/$CA_ADMIN_USER_PASS/g" ${K8STEMPLATES}/fabric-deployment-rca.yaml > ${K8SYAML}/fabric-deployment-rca-$ORG.yaml
            #sudo chown 1003:1003 $DATA/organizations/fabric-ca/ordererRCA/fabric-ca-server-config.yaml
        done
        rcaport=$((rcaport+5))
        for ORG in $PEER_ORGS; do
            RCA_PORTS_IN_USE+=( ["rca-$ORG"]=$rcaport )
            initOrgVars $ORG
            getDomain $ORG
            port=7054
            sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" $DATA/organizations/fabric-ca/rca/fabric-ca-server-config.yaml > $DATA/organizations/fabric-ca/${ORG}RCA/fabric-ca-server-config.yaml
            sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%FABRICORGS%/${FABRICORGS}/g" -e "s/%PORT%/${port}/g" -e "s/%NODEPORT%/${rcaport}/g" -e "s/%FABRIC_TAG%/${FABRIC_TAG}/g" -e "s/%RCA%/${ORG}/g" -e "s/%CA_ADMIN_USER_PASS%/$CA_ADMIN_USER_PASS/g" ${K8STEMPLATES}/fabric-deployment-rca.yaml > ${K8SYAML}/fabric-deployment-rca-$ORG.yaml
            #sudo chown 1003:1003 $DATA/organizations/fabric-ca/${ORG}RCA/fabric-ca-server-config.yaml
        done
    done
    declare -p RCA_PORTS_IN_USE > $SCRIPTS/rca-ports.sh
    
}

function genICA {
    log "Generating ICA K8s YAML files"
    if [ -f $SCRIPTS/ica-ports.sh ]; then
        log "Loading the ports used by ICAs"
        source $SCRIPTS/ica-ports.sh
        for portValue in "${ICA_PORTS_IN_USE[@]}"
        do
          if [[ portValue -gt icaport ]]; then
            icaport=$((portValue+0))
          fi
        done
        icaport=$((icaport+5))
    fi
    log "The starting ICA port is: ${icaport}"
    for ORG in $ORGS; do
        getDomain $ORG
        # Check if the ICA already has a port assigned
        local portAssigned=false
        for key in ${!ICA_PORTS_IN_USE[@]}
        do
            if [ "${key}" == "ica-$ORG" ] ; then
                log "ICA ${key} already has port assigned: ${ICA_PORTS_IN_USE[${key}]} "
                portAssigned=true
                break
            fi
        done
        if [ "$portAssigned" = true ] ; then
            continue
        fi
        # Find a port number that hasn't been used
        while true
        do
            local portInUse=false
            for key in ${!ICA_PORTS_IN_USE[@]}
            do
                if [ "${ICA_PORTS_IN_USE[${key}]}" -eq "$icaport" ] ; then
                    icaport=$((icaport+5))
                    portInUse=true
                    break
                fi
            done
            if [ "$portInUse" = false ] ; then
                break
            fi
        done
        ICA_PORTS_IN_USE+=( ["ica-$ORG"]=$icaport )
        log "Port assigned to ica: ica-$ORG is $icaport"
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%FABRICORGS%/${FABRICORGS}/g" -e "s/%PORT%/${icaport}/g" -e "s/%FABRIC_TAG%/${FABRIC_TAG}/g" ${K8STEMPLATES}/fabric-deployment-ica.yaml > ${K8SYAML}/fabric-deployment-ica-$ORG.yaml
        icaport=$((icaport+1))
        ICA_PORTS_IN_USE+=( ["ica-notls-$ORG"]=$icaport )
        log "Port assigned to ica notls: ica-notls-$ORG is $icaport"
    done
    declare -p ICA_PORTS_IN_USE > $SCRIPTS/ica-ports.sh
}


function genRegisterOrderer {
    log "Generating Register Orderer K8s YAML files"
    for ORG in $ORDERER_ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%FABRIC_TAG%/${FABRIC_TAG}/g" ${K8STEMPLATES}/fabric-deployment-register-orderer.yaml > ${K8SYAML}/fabric-deployment-register-orderer-$ORG.yaml
    done
}

function genRegisterPeers {
    log "Generating Register Peer K8s YAML files"
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%FABRIC_TAG%/${FABRIC_TAG}/g" ${K8STEMPLATES}/fabric-deployment-register-peer.yaml > ${K8SYAML}/fabric-deployment-register-peer-$ORG.yaml
    done
}

function genChannelArtifacts {
    log "Generating Channel Artifacts Setup K8s YAML files"
    #get the first orderer org. Setup only needs to run once, against the orderer org
    orgsarr=($ORDERER_ORGS)
    #ORG=${orgsarr[0]}
    peerorgsarr=($PEER_ORGS)
    PEER_ORG=${peerorgsarr[0]}
    getDomain $PEER_ORG
    sed -e "s/%ORG%/${orgsarr}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%PEER_ORG%/${peerorgsarr}/g" -e "s/%FABRIC_TAG%/${FABRIC_TAG}/g" ${K8STEMPLATES}/fabric-deployment-channel-artifacts.yaml > ${K8SYAML}/fabric-deployment-channel-artifacts.yaml
}

function genOrderer {
    FABRIC_TAG_ORDERER="2.3"
    log "Generating Orderer K8s YAML files"
    if [ -f $SCRIPTS/orderer-ports.sh ]; then
        log "Loading the ports used by Orderer"
        source $SCRIPTS/orderer-ports.sh
        for portValue in "${ORDERER_PORTS_IN_USE[@]}"
        do
          if [[ portValue -gt ordererport ]]; then
            ordererport=$((portValue+0))
          fi
        done
        ordererport=$((ordererport+5))
    fi
    log "The starting ORDERER port is: ${ordererport}"
    for ORG in $ORDERER_ORGS; do
        getDomain $ORG
        local COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            # Check if the Orderer already has a port assigned
            local portAssigned=false
            for key in ${!ORDERER_PORTS_IN_USE[@]}
            do
                if [ "${key}" == "orderer$COUNT-$ORG" ] ; then
                    log "Orderer ${key} already has port assigned: ${ORDERER_PORTS_IN_USE[${key}]} "
                    portAssigned=true
                    break
                fi
            done
            if [ "$portAssigned" = true ] ; then
                COUNT=$((COUNT+1))
                continue
            fi
            # Find a port number that hasn't been used
            while true
            do
                local portInUse=false
                for key in ${!ORDERER_PORTS_IN_USE[@]}
                do
                    if [ "${ORDERER_PORTS_IN_USE[${key}]}" -eq "$ordererport" ] ; then
                        ordererport=$((ordererport+5))
                        portInUse=true
                        break
                    fi
                done
                if [ "$portInUse" = false ] ; then
                    break
                fi
            done
            ORDERER_PORTS_IN_USE+=( ["orderer$COUNT-$ORG"]=$ordererport )
            log "Port assigned to orderer: orderer$COUNT-$ORG is $ordererport"

            if [ $COUNT -eq 1 ]; then
                
                sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" -e "s/%NODEPORT%/${ordererport}/g" -e "s/%NODEPORTMETRICS%/$((ordererport+5))/g" -e "s/%FABRIC_TAG%/${FABRIC_TAG_ORDERER}/g" ${K8STEMPLATES}/fabric-deployment-orderer-metrics.yaml > ${K8SYAML}/fabric-deployment-orderer$COUNT-$ORG-metrics.yaml
                ordererport=$((ordererport+10))
            else
                sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" -e "s/%NODEPORT%/${ordererport}/g" -e "s/%FABRIC_TAG%/${FABRIC_TAG_ORDERER}/g" ${K8STEMPLATES}/fabric-deployment-orderer.yaml > ${K8SYAML}/fabric-deployment-orderer$COUNT-$ORG.yaml
                sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" ${K8STEMPLATES}/fabric-nlb-orderer.yaml > ${K8SYAML}/fabric-nlb-orderer$COUNT-$ORG.yaml
            fi
            COUNT=$((COUNT+1))
        done
    done
    declare -p ORDERER_PORTS_IN_USE > $SCRIPTS/orderer-ports.sh
}

function genBuilderConfig {
    log "Generating builder-config K8s YAML files"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g"  ${K8STEMPLATES}/fabric-configmap-builder-config.yaml > ${K8SYAML}/fabric-configmap-builder-config.yaml    
    done
}

function genPeers {
    log "Generating Peer K8s YAML files"
    if [ -f $SCRIPTS/peer-ports.sh ]; then
        log "Loading the ports used by peers"
        source $SCRIPTS/peer-ports.sh
        for portValue in "${PEER_PORTS_IN_USE[@]}"
        do
          if [[ portValue -gt peerport ]]; then
            peerport=$((portValue+0))
          fi
        done
        peerport=$((peerport+5))
    fi
    log "The starting PEER port is: ${peerport}"
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        local COUNT=1
        
        PORTCHAIN=$peerport
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            if [ $COUNT -eq 1 ]; then
                #the first peer of an org defaults to the anchor peer
                sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" ${K8STEMPLATES}/fabric-nlb-anchor-peer.yaml > ${K8SYAML}/fabric-nlb-anchor-peer$COUNT-$ORG.yaml
            fi
            # Check if the peer already has a port assigned
            local portAssigned=false
            for key in ${!PEER_PORTS_IN_USE[@]}
            do
                if [ "${key}" == "peer$COUNT-$ORG" ] ; then
                    log "Peer ${key} already has port assigned: ${PEER_PORTS_IN_USE[${key}]} "
                    portAssigned=true
                    break
                fi
            done
            if [ "$portAssigned" = true ] ; then
                COUNT=$((COUNT+1))
                continue
            fi
            # Find a port number that hasn't been used
            PORTCHAIN=$((PORTCHAIN+2))
            while true
            do
                local portInUse=false
                for key in ${!PEER_PORTS_IN_USE[@]}
                do
                    if [ "${PEER_PORTS_IN_USE[${key}]}" -eq "$PORTCHAIN" ] ; then
                        PORTCHAIN=$((PORTCHAIN+5))
                        portInUse=true
                        break
                    fi
                done
                if [ "$portInUse" = false ] ; then
                    break
                fi
            done
            PORTEND=$((PORTCHAIN-1))
            PEER_PORTS_IN_USE+=( ["peer$COUNT-$ORG"]=$PORTCHAIN )
            log "Port assigned to peer: peer$COUNT-$ORG is $PORTCHAIN"
            sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" -e "s/%NODEPORT%/${PORTCHAIN}/g" -e "s/%NODEPORTEVENT%/$((PORTCHAIN+5))/g" -e "s/%NODEPORTCOUCH%/$((PORTCHAIN+10))/g" -e "s/%NODEPORTMETRICS%/$((PORTCHAIN+15))/g"  -e "s/%FABRIC_TAG%/${FABRIC_TAG}/g" ${K8STEMPLATES}/fabric-deployment-peer.yaml > ${K8SYAML}/fabric-deployment-peer$COUNT-$ORG.yaml
            PORTCHAIN=$((PORTCHAIN+20))
            COUNT=$((COUNT+1))
        done
    done
    declare -p PEER_PORTS_IN_USE > $SCRIPTS/peer-ports.sh
}

function genCLIs {
    log "Generating Peers CLI K8s YAML files"
    for ORG in $PEER_ORGS; do
        initOrgVars $ORG
        orgsarr=($ORDERER_ORGS)
        ORDERER_ORG=${orgsarr[0]}
        getDomain $ORDERER_ORG
        ORDERER_DOMAIN=$DOMAIN
        getDomain $ORG
        FABRIC_IMAGE_TAG=2.3
        local COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            sed -e "s/%ORG%/${ORG}/g" -e "s/%ORDERER_ORG%/${ORDERER_ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%ORDERER_DOMAIN%/${ORDERER_DOMAIN}/g" -e "s/%NUM%/${COUNT}/g"  -e "s/%ADMIN_NAME%/${ADMIN_NAME}/g" -e "s/%FABRIC_TAG%/${FABRIC_IMAGE_TAG}/g" ${K8STEMPLATES}/fabric-deployment-cli.yaml > ${K8SYAML}/fabric-deployment-cli-peer$COUNT-$ORG.yaml
            COUNT=$((COUNT+1))
        done
    done
}

function genCCDeploy {
    log "Generating chaincode deployment K8s YAML files"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g" ${K8STEMPLATES}/fabric-deployment-chaincode.yaml > ${K8SYAML}/fabric-deployment-chaincode-$ORG.yaml  
    done
}

function genAddOrg {
    log "Generating Add Org Peer K8s YAML files"
    getAdminOrg
    getDomain $ADMINORG
    sed -e "s/%ADMINORG%/${ADMINORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%FABRIC_TAG%/2.3/g" ${K8STEMPLATES}/fabric-job-addorg-setup.yaml > k8s-$ADMINORG/fabric-job-addorg-setup-$ADMINORG.yaml
}

function genConfigMap {
    log "Generating Connection profile configmap K8s YAML files"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g" ${K8STEMPLATES}/fabric-configmap-connection-profile.yaml > ${K8SYAML}/fabric-configmap-connection-profile-$ORG.yaml
    done
    #cp ${K8STEMPLATES}/fabric-configmap-connection-profile.yaml  ${K8SYAML}/fabric-configmap-connection-profile.yaml
}


function genAPI {
    log "Generating API K8s YAML files"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g" ${K8STEMPLATES}/fabric-deployment-api.yaml > ${K8SYAML}/fabric-deployment-api-$ORG.yaml
    done
    #cp ${K8STEMPLATES}/fabric-deployment-api.yaml  ${K8SYAML}/fabric-deployment-api.yaml
}

function genFrontend {
    log "Generating Frontend K8s YAML files"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g" ${K8STEMPLATES}/fabric-deployment-frontend.yaml > ${K8SYAML}/fabric-deployment-frontend-$ORG.yaml
    done
    #cp ${K8STEMPLATES}/fabric-deployment-frontend.yaml  ${K8SYAML}/fabric-deployment-frontend.yaml
}

function genExplorerDB {
    log "Generating Hyperledger Explorer DB K8s YAML files"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g" ${K8STEMPLATES}/fabric-deployment-explorerdb.yaml > ${K8SYAML}/fabric-deployment-explorerdb-$ORG.yaml
    done
    #cp ${K8STEMPLATES}/fabric-deployment-explorerdb.yaml  ${K8SYAML}/fabric-deployment-explorerdb.yaml
}

function genExplorer {
    log "Generating Hyperledger Explorer K8s YAML files"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g"  ${K8STEMPLATES}/fabric-deployment-explorer.yaml > ${K8SYAML}/fabric-deployment-explorer-$ORG.yaml
    done
    #cp ${K8STEMPLATES}/fabric-deployment-explorer.yaml  ${K8SYAML}/fabric-deployment-explorer.yaml
}

function genPrometheus {
    log "Generating Prometheus K8s YAML files"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g" ${K8STEMPLATES}/fabric-deployment-prometheus.yaml > ${K8SYAML}/fabric-deployment-prometheus-$ORG.yaml
    done
    #cp ${K8STEMPLATES}/fabric-deployment-prometheus.yaml  ${K8SYAML}/fabric-deployment-prometheus.yaml
}

function genGrafanaConfig {
    log "Generating Grafana Config K8s YAML files"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g" ${K8STEMPLATES}/fabric-configmap-grafana.yaml > ${K8SYAML}/fabric-configmap-grafana-$ORG.yaml
    done
    #cp ${K8STEMPLATES}/fabric-configmap-grafana.yaml  ${K8SYAML}/fabric-configmap-grafana.yaml
}

function genGrafana {
    log "Generating Grafana K8s YAML files"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g" ${K8STEMPLATES}/fabric-deployment-grafana.yaml > ${K8SYAML}/fabric-deployment-grafana-$ORG.yaml
    done
    #cp ${K8STEMPLATES}/fabric-deployment-grafana.yaml  ${K8SYAML}/fabric-deployment-grafana.yaml
}

function genIngressForPayer {
    log "Generating Ingress K8s YAML files"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g" ${K8STEMPLATES}/fabric-ingress-payer.yaml > ${K8SYAML}/fabric-ingress-$ORG.yaml
    done
    #cp ${K8STEMPLATES}/fabric-deployment-grafana.yaml  ${K8SYAML}/fabric-deployment-grafana.yaml
}