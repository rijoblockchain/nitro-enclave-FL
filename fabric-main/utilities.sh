#!/usr/bin/env bash


REPO=healthcare-hlf-k8
DATA=/opt/share/efs
#DATA=/opt/share
SCRIPTS=$DATA/scripts
source $SCRIPTS/env.sh
K8SYAML=k8s

function copyRCA {
    if [ $# -ne 1 ]; then
        echo "Usage: copyRCA  <data-dir - probably something like /opt/share2/>"
        exit 1
    fi
    local DATA=$1
    echo "Making directory at $DATA"
    for ORG in $ORGS; do
        getDomain $ORG
        mkdir -p $DATA/organizations/fabric-ca/rca-$ORG
        cp -R $DATA/fabric-ca/rca/* $DATA/organizations/fabric-ca/rca-$ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g"  $DATA/organizations/fabric-ca/rca-$ORG/fabric-ca-server-config.yaml > $DATA/organizations/fabric-ca/rca-$ORG/tmp.yaml && mv $DATA/organizations/fabric-ca/rca-$ORG/tmp.yaml $DATA/organizations/fabric-ca/rca-$ORG/fabric-ca-server-config.yaml
        mkdir -p $DATA/organizations/fabric-ca/ica-$ORG
        cp -R $DATA/fabric-ca/ica/* $DATA/organizations/fabric-ca/ica-$ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g"  $DATA/organizations/fabric-ca/ica-$ORG/fabric-ca-server-config.yaml > $DATA/organizations/fabric-ca/ica-$ORG/tmp.yaml && mv $DATA/organizations/fabric-ca/ica-$ORG/tmp.yaml $DATA/organizations/fabric-ca/ica-$ORG/fabric-ca-server-config.yaml
    done

    sudo rm -rf $DATA/fabric-ca
    
}

function copyCACERT {
    if [ $# -ne 1 ]; then
        echo "Usage: copyRCA  <data-dir - probably something like /opt/share2/>"
        exit 1
    fi
    
    local DATA=$1
    for ORG in $ORGS; do
        getDomain $ORG
        cp -R $DATA/organizations/fabric-ca/rca-$ORG/ca-cert.pem $DATA/data/$ORG-ca-cert.pem
    done
    
}

function makeDirsForOrg {
    if [ $# -ne 1 ]; then
        echo "Usage: makeDirs <data-dir - probably something like /opt/share/>"
        echo "input args are '$@'"
        exit 1
    fi
    local DATA=$1
    echo "Making directories at $DATA"
    cd $DATA
    for ORG in $ORGS; do
        #mkdir -p wallet/${ORG}
        mkdir -p organizations/fabric-ca/${ORG}RCA
        mkdir -p tls-ca-$ORG
        mkdir -p rca-$ORG
        mkdir -p ica-$ORG
    done
    sudo chmod 777 organizations -R

}

function createNamespaces {
    if [ $# -ne 2 ]; then
        echo "Usage: createNamespaces <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    log "Creating K8s namespaces"
    cd $HOME
    for ORG in $PEER_ORGS; do
        kubectl apply -f $REPO/$K8SYAML/fabric-namespace-$ORG.yaml
    done
}

function startPVC {
    if [ $# -ne 2 ]; then
        echo "Usage: startPVC <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    log "Starting PVC in K8s"
    cd $HOME
    for ORG in $PEER_ORGS; do
        kubectl apply -f $REPO/$K8SYAML/fabric-pvc-$ORG.yaml
        sleep 2
    done
}

function startRCA {
    if [ $# -ne 2 ]; then
        echo "Usage: startRCA <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    
    cd $HOME
    log "Starting RCA in K8s"
    for ORG in $ORGS; do
        kubectl apply -f $REPO/$K8SYAML/fabric-deployment-rca-$ORG.yaml
        confirmDeployments $ORG
    done
    #make sure the svc starts, otherwise subsequent commands may fail
    
}

function startNewOrgRCA {
    if [ $# -ne 2 ]; then
        echo "Usage: startRCA <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    
    cd $HOME
    log "Starting RCA in K8s"
    for ORG in $PEER_ORGS; do
        kubectl apply -f $REPO/$K8SYAML/fabric-deployment-rca-$ORG.yaml
        confirmDeployments $ORG
    done
    
    #make sure the svc starts, otherwise subsequent commands may fail   
    
}

function startICA {
    if [ $# -ne 2 ]; then
        echo "Usage: startICA <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Starting ICA in K8s"
    for ORG in $ORGS; do
        kubectl apply -f $REPO/$K8SYAML/fabric-deployment-ica-$ORG.yaml
        confirmDeployments $ORG
    done
    #make sure the svc starts, otherwise subsequent commands may fail
    
}

function startRegisterOrderers {
    if [ $# -ne 2 ]; then
        echo "Usage: startRegisterOrderers <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Registering Fabric Orderers"
    for ORG in $ORDERER_ORGS; do
        kubectl apply -f $REPO/$K8SYAML/fabric-deployment-register-orderer-$ORG.yaml
        confirmDeployments $ORG
    done
    
    
}

function startRegisterPeers {
    if [ $# -ne 2 ]; then
        echo "Usage: startRegisterPeers <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    sleep 30s
    cd $HOME
    log "Registering Fabric Peers"
    for ORG in $PEER_ORGS; do
         kubectl apply -f $REPO/$K8SYAML/fabric-deployment-register-peer-$ORG.yaml
         confirmDeployments $ORG
    done
    
}

function updateChannelArtifacts {
    set +e
    if [ $# -ne 2 ]; then
        echo "Usage: updateChannelArtifacts <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    #local DATADIR=$3
    
    #sudo chmod 777 -R $DATADIR/organizations/ordererOrganizations/payer.com/orderers/*

    log "Generating Fabric Channel Artifacts"
    #stop the existing channel artifacts pod. Restart it to regenerate a new configtx.yaml
    #and new artifacts
    cd $HOME
    stopChannelArtifacts $HOME $REPO
    sleep 5
    kubectl apply -f $REPO/$K8SYAML/fabric-deployment-channel-artifacts.yaml
    confirmDeployments $ORG
    set -e
}

function startOrderer {
    if [ $# -ne 2 ]; then
        echo "Usage: startOrderer <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    sleep 15s
    log "Starting Orderer in K8s"
    for ORG in $ORDERER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
        if [ $COUNT -eq 1 ]; then
            kubectl apply -f $REPO/$K8SYAML/fabric-deployment-orderer$COUNT-$ORG-metrics.yaml
            confirmDeployments $ORG
        else 
            kubectl apply -f $REPO/$K8SYAML/fabric-deployment-orderer$COUNT-$ORG.yaml
            confirmDeployments $ORG
        fi
        COUNT=$((COUNT+1))        
      done
    done
    
}

function startOrdererNLB {
    if [ $# -ne 2 ]; then
        echo "Usage: startOrdererNLB <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    echo "Starting Network Load Balancer service for Orderer"
    # Do not create an NLB for the first orderer, but do create one for all others
    for ORG in $ORDERER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
        if [ $COUNT -gt 1 ]; then
            kubectl apply -f $REPO/k8s/fabric-nlb-orderer$COUNT-$ORG.yaml
        fi
        COUNT=$((COUNT+1))
      done
    done

    #Wait for NLB service to be created and hostname to be available. This could take a few seconds
    #Note the loop here starts from '2' - we ignore the first orderer as it does not use an NLB
    EXTERNALORDERERADDRESSES=''
    for ORG in $ORDERER_ORGS; do
      local COUNT=2
      getDomain $ORG
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
        NLBHOSTNAME=$(kubectl get svc orderer${COUNT}-${ORG}-nlb -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[*].hostname}')
        NLBHOSTPORT=$(kubectl get svc orderer${COUNT}-${ORG}-nlb -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].port}')
        while [[ "${NLBHOSTNAME}" != *"elb"* ]]; do
            echo "Waiting on AWS to create NLB for Orderer. Hostname = ${NLBHOSTNAME}"
            NLBHOSTNAME=$(kubectl get svc orderer${COUNT}-${ORG}-nlb -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[*].hostname}')
            NLBHOSTPORT=$(kubectl get svc orderer${COUNT}-${ORG}-nlb -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].port}')
            sleep 10
        done
        local ORDERERHOST=orderer${COUNT}-${ORG}-${DOMAIN}
        # Update the orderer deployment yaml with the orderer NLB DNS endpoint. This will allow remote connection from a peer,
        # and is necessary to ensure the orderer generates a TLS cert with the correct endpoint address.
        # This is only done if: there is more than 1 orderer AND $FABRIC_NETWORK_TYPE == "PROD" (in fact, this function is only
        # called if we are setting up a PROD network)
        if [ $COUNT -gt 1 ]; then
            echo "replacing host: ${ORDERERHOST} with NLB DNS: ${NLBHOSTNAME} in file $REPO/k8s/fabric-deployment-orderer${COUNT}-${ORG}.yaml"
            sed -e "s/${ORDERERHOST}/${NLBHOSTNAME}/g" -i $REPO/k8s/fabric-deployment-orderer$COUNT-$ORG.yaml
            # Store the NLB endpoint for the orderers. These NLB endpoints will find their way into configtx.yaml. See
            # the code after the for-loop below where scripts.env is updated. This ensures the NLB endpoints are in the
            # genesis config block for the channel, and allows remote peers to connect to the orderer.
            if [ $COUNT != $NUM_ORDERERS ]; then
                EXTERNALORDERERADDRESSES="${EXTERNALORDERERADDRESSES}        - ${NLBHOSTNAME}:${NLBHOSTPORT}\n"
            else
                EXTERNALORDERERADDRESSES="${EXTERNALORDERERADDRESSES}        - ${NLBHOSTNAME}:${NLBHOSTPORT}"
            fi
        else
            sed -e "s/${ORDERERHOST}/${orderer${COUNT}-${ORG}}/g" -i $REPO/k8s/fabric-deployment-orderer$COUNT-$ORG.yaml
        fi
        # Only the 2nd orderer is updated with the NLB endpoint. The 1st orderer retains a local orderer endpoint for connection
        # from local peers.
        if [ $COUNT -eq 2 ]; then
            # Set the two ENV variables below in scripts/env.sh. These are used when setting the context for the
            # orderer. We set the context in env.sh, in the function initOrdererVars. If we are setting the context
            # for the 2nd orderer, we want to point the ORDERER_HOST ENV var to the NLB endpoint.
            echo "replacing host: ${ORDERERHOST} with NLB DNS: ${NLBHOSTNAME} in file ${SCRIPTS}/env.sh"
            sed -e "s/EXTERNALORDERERHOSTNAME=\"\"/EXTERNALORDERERHOSTNAME=\"${NLBHOSTNAME}\"/g" -i $SCRIPTS/env.sh
            sed -e "s/EXTERNALORDERERPORT=\"\"/EXTERNALORDERERPORT=\"${NLBHOSTPORT}\"/g" -i $SCRIPTS/env.sh
        fi
        COUNT=$((COUNT+1))
      done
    done
    # update env.sh with the Orderer NLB external hostname. This will be used in scripts/gen-channel-artifacts.sh, and
    # add the hostnames to configtx.yaml. This should be the endpoint for the 2nd orderer.
    echo "Updating env.sh with Orderer NLB endpoints: ${EXTERNALORDERERADDRESSES}"
    sed -e "s/EXTERNAL_ORDERER_ADDRESSES=\"\"/EXTERNAL_ORDERER_ADDRESSES=\"${EXTERNALORDERERADDRESSES}\"/g" -i $SCRIPTS/env.sh
}

# This function is only called if: $FABRIC_NETWORK_TYPE == "PROD"
function startAnchorPeerNLB {
    if [ $# -ne 2 ]; then
        echo "Usage: startAnchorPeerNLB <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    echo "Starting Network Load Balancer service for Anchor Peers"
    for ORG in $PEER_ORGS; do
      kubectl apply -f $REPO/k8s/fabric-nlb-anchor-peer1-$ORG.yaml
    done

    #wait for service to be created and hostname to be available. This could take a few seconds
    EXTERNALANCHORPEERADDRESSES=""
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        NLBHOSTNAME=$(kubectl get svc peer1-${ORG}-nlb -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[*].hostname}')
        NLBHOSTPORT=$(kubectl get svc peer1-${ORG}-nlb -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].port}')
        while [[ "${NLBHOSTNAME}" != *"elb"* ]]; do
            echo "Waiting on AWS to create NLB for Anchor Peers. Hostname = ${NLBHOSTNAME}"
            NLBHOSTNAME=$(kubectl get svc peer1-${ORG}-nlb -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[*].hostname}')
            NLBHOSTPORT=$(kubectl get svc peer1-${ORG}-nlb -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].port}')
            sleep 10
        done
        EXTERNALANCHORPEERADDRESSES="${EXTERNALANCHORPEERADDRESSES} ${NLBHOSTNAME}:${NLBHOSTPORT}"
        echo "adding ${NLBHOSTNAME}:${NLBHOSTPORT} to EXTERNALANCHORPEERADDRESSES: ${EXTERNALANCHORPEERADDRESSES}"
        # Update the peer deployment yaml with the anchor peer DNS endpoint. Assume peer1 is the anchor peer for each org.
        # This allows peers deployed in different regions/accounts to communicate.
        # This is only done if: $FABRIC_NETWORK_TYPE == "PROD" (in fact, this function is only called if we are setting up a PROD network)
        local COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            local PEERHOST=peer$COUNT-${ORG}-${DOMAIN}
            if [ $COUNT -eq 1 ]; then
                echo "replacing host: ${PEERHOST} with NLB DNS: ${NLBHOSTNAME} in file $REPO/k8s/fabric-deployment-peer1-${ORG}.yaml"
                sed -e "s/${PEERHOST}/${NLBHOSTNAME}/g" -i $REPO/k8s/fabric-deployment-peer$COUNT-$ORG.yaml
            else
                HOST=
                sed -e "s/${PEERHOST}/peer$COUNT-${ORG}/g" -i $REPO/k8s/fabric-deployment-peer$COUNT-$ORG.yaml
            fi
            COUNT=$((COUNT+1))
        done
    done
    #update env.sh with the Anchor Peer NLB external hostname. This will be used in scripts/gen-channel-artifacts.sh, and
    # add the hostnames to configtx.yaml
    echo "Updating env.sh with Anchor Peer NLB endpoints: ${EXTERNALANCHORPEERADDRESSES}"
    sed -e "s/EXTERNAL_ANCHOR_PEER_ADDRESSES=\"\"/EXTERNAL_ANCHOR_PEER_ADDRESSES=\"${EXTERNALANCHORPEERADDRESSES}\"/g" -i $SCRIPTS/env.sh
    sed -e "s/EXTERNALANCHORPEERHOSTNAME=\"\"/EXTERNALANCHORPEERHOSTNAME=\"${NLBHOSTNAME}\"/g" -i $SCRIPTS/env.sh

}


function createBuilderConfig {
    if [ $# -ne 2 ]; then
        echo "Usage: createBuilderConfig <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    sleep 10s
    log "building Configmap in K8s"
    for ORG in $PEER_ORGS; do
         kubectl apply -f $REPO/$K8SYAML/fabric-configmap-builder-config.yaml
         confirmDeployments $ORG
    done
        
}

function startPeers {
    if [ $# -ne 2 ]; then
        echo "Usage: startPeers <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    sleep 10s
    log "Starting Peers in K8s"
    for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
        if [[ $EXTERNALANCHORPEER ]]; then
           IFS=':' read -r -a arr <<< "$EXTERNALANCHORPEER"
           PEER=${arr[0]}
           PORT=${arr[1]}
        fi
        kubectl apply -f $REPO/$K8SYAML/fabric-deployment-peer$COUNT-$ORG.yaml
        COUNT=$((COUNT+1))
        confirmDeployments $ORG
      done
   done
}

function startCLIs {
    if [ $# -ne 2 ]; then
        echo "Usage: startCLIs <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Starting Peers CLI in K8s"
    for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do        
        kubectl apply -f $REPO/$K8SYAML/fabric-deployment-cli-peer$COUNT-$ORG.yaml
        COUNT=$((COUNT+1))
        confirmDeployments $ORG
      done
   done
}

function createAppChannel {
    if [ $# -ne 2 ]; then
        echo "Usage: createAppChannel <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Creating Application channel in K8s"
    for ORG in $PEER_ORGS; do
      local COUNT=1
      getDomain $ORG
      #while [[ "$COUNT" -le $NUM_PEERS ]]; do
        kubectl exec --stdin --tty  $(kubectl get pods -n $NAMESPACE |grep cli-peer$COUNT-$ORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/createAppChannel.sh $DOMAIN $ORDERER_ORGS $ORG
        COUNT=$((COUNT+1))
        confirmDeployments $ORG  
      #done
    done
}

function joinChannel {
    if [ $# -ne 2 ]; then
        echo "Usage: joinChannel <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Join channel"
    for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
        kubectl exec --stdin --tty  $(kubectl get pods -n $NAMESPACE |grep cli-peer$COUNT-$ORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/joinChannel.sh 
        COUNT=$((COUNT+1))
        confirmDeployments $ORG
      done
   done
}

function updateAnchorPeer {
    if [ $# -ne 2 ]; then
        echo "Usage: updateAnchorPeer <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Update Anchor Peers"
    for ORG in $PEER_ORGS; do
      local COUNT=1
      getDomain $ORG
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
        if [ $COUNT -eq 1 ]; then
            kubectl exec --stdin --tty  $(kubectl get pods -n $NAMESPACE |grep cli-peer$COUNT-$ORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/updateAnchorPeer.sh
            confirmDeployments $ORG
        fi
        COUNT=$((COUNT+1))
      done
   done
}

function packagingChaincode {
    if [ $# -ne 3 ]; then
        echo "Usage: packagingChaincode <home-dir> <repo-name> <datadir-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local DATADIR=$3
    cd $DATADIR/chaincode/basic/packaging/
    log "Packaging chaincode"
    for ORG in $PEER_ORGS; do
        sed -e "s/%ORG%/${ORG}/g" ${DATADIR}/chaincode/basic/packaging/connection.json > ${DATADIR}/chaincode/basic/packaging/tmp.json  && mv tmp.json connection.json
    done
    tar cfz code.tar.gz connection.json
    tar cfz basic-org1.tgz code.tar.gz metadata.json
    rm -rf code.tar.gz
}

function installingChaincode {
    if [ $# -ne 2 ]; then
        echo "Usage: installingChaincode <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Installing Chaincode"
    for ORG in $PEER_ORGS; do
      local COUNT=1
      getDomain $ORG
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
        kubectl exec --stdin --tty  $(kubectl get pods -n  $NAMESPACE |grep cli-peer$COUNT-$ORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/install.sh
        confirmDeployments $ORG
        COUNT=$((COUNT+1))
      done
   done
}

function queryInstalled {
    if [ $# -ne 2 ]; then
        echo "Usage: queryInstalled <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Query installed chaincode"
    for ORG in $PEER_ORGS; do
      local COUNT=1
      getDomain $ORG
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
        kubectl exec --stdin --tty  $(kubectl get pods -n  $NAMESPACE |grep cli-peer$COUNT-$ORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/queryInstalled.sh
        confirmDeployments $ORG
        COUNT=$((COUNT+1))
      done
   done
}

function deployChaincode {
    if [ $# -ne 3 ]; then
        echo "Usage: deployChaincode <home-dir> <repo-name> <datadir-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local DATADIR=$3
    USERNAME=rijojani
    IMAGE=basic-cc-hlf:1.0
    cd $HOME
    # Below command returns the package id converted to string
    PACKAGE_ID=$(printf "%s" $(awk -F'Chaincode code package identifier: ' '{print $2}' /opt/share/efs/chaincode/basic/packaging/log.txt)) 
    echo $PACKAGE_ID
    log "Starting chaincode in K8s"
    for ORG in $PEER_ORGS; do
        sed -e "s/%USERNAME%/${USERNAME}/g" -e "s/%IMAGE%/${IMAGE}/g" -e "s/%CHAINCODE_ID%/${PACKAGE_ID}/g" $REPO/$K8SYAML/fabric-deployment-chaincode-$ORG.yaml > $REPO/$K8SYAML/tmp.yaml && mv $REPO/$K8SYAML/tmp.yaml $REPO/$K8SYAML/fabric-deployment-chaincode-$ORG.yaml
        kubectl apply -f $REPO/$K8SYAML/fabric-deployment-chaincode-$ORG.yaml
        confirmDeployments $ORG
    done
}

function approveChaincode {
    if [ $# -ne 3 ]; then
        echo "Usage: approveChaincode <home-dir> <repo-name> <datadir-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local DATADIR=$3
    cd $HOME
    log "Approve chaincode"
    for ORG in $PEER_ORGS; do
      COUNT=1
      getDomain $ORG
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
        if [ $COUNT -eq 1 ]; then
            kubectl exec --stdin --tty  $(kubectl get pods -n $NAMESPACE |grep cli-peer$COUNT-$ORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/approveChaincode.sh
            confirmDeployments $ORG
        fi
        COUNT=$((COUNT+1))
      done
   done
}

function checkCommitReadiness {
    if [ $# -ne 3 ]; then
        echo "Usage: checkCommitReadiness <home-dir> <repo-name> <datadir-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local DATADIR=$3
    cd $HOME
    log "Check commit readiness"
    for ORG in $PEER_ORGS; do
      COUNT=1
      getDomain $ORG
      kubectl exec --stdin --tty  $(kubectl get pods -n $NAMESPACE |grep cli-peer$COUNT-$ORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/checkCommitReadiness.sh
      confirmDeployments $ORG
    done
}

function commitChaincode {
    if [ $# -ne 3 ]; then
        echo "Usage: commitChaincode <home-dir> <repo-name> <datadir-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local DATADIR=$3
    cd $HOME
    log "Commit chaincode"
    for ORG in $PEER_ORGS; do
      COUNT=1
      getDomain $ORG
      kubectl exec --stdin --tty  $(kubectl get pods -n $NAMESPACE |grep cli-peer$COUNT-$ORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/commitChaincode.sh
      confirmDeployments $ORG
    done
}

function queryCommitted {
    if [ $# -ne 2 ]; then
        echo "Usage: queryCommitted <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Query Committed"
    for ORG in $PEER_ORGS; do
      local COUNT=1
      kubectl exec --stdin --tty  $(kubectl get pods -n  $NAMESPACE |grep cli-peer$COUNT-$ORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/queryCommitted.sh
      confirmDeployments $ORG
   done
}

function initChaincode {
    if [ $# -ne 2 ]; then
        echo "Usage: initChaincode <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Initialize chaincode if --init-required is provided in commit"
    for ORG in $PEER_ORGS; do
      local COUNT=1
      kubectl exec --stdin --tty  $(kubectl get pods -n  $NAMESPACE |grep cli-peer$COUNT-$ORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/initChaincode.sh
      confirmDeployments $ORG
   done
}

function updateEnv {
    if [ $# -ne 6 ]; then
        echo "Usage: updateEnv <home-dir> <repo-name> <datadir-name> <domain-name> <orderer-name> <peer-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local DATADIR=$3
    log "updating env.sh"

    sed -r -i.bak "s/ORDERER_DOMAINS=([[:graph:]]+)/ORDERER_DOMAINS=$4/" $HOME/$REPO/prerequisite/scripts/env.sh
    sed -r -i.bak "s/PEER_DOMAINS=([[:graph:]]+)/PEER_DOMAINS=$4/" $HOME/$REPO/prerequisite/scripts/env.sh
    sed -r -i.bak "s/ORDERER_ORGS=([[:graph:]]+)/ORDERER_ORGS=$5/" $HOME/$REPO/prerequisite/scripts/env.sh
    sed -r -i.bak "s/PEER_ORGS=([[:graph:]]+)/PEER_ORGS=$6/" $HOME/$REPO/prerequisite/scripts/env.sh

    cp $HOME/$REPO/prerequisite/scripts/env.sh $DATADIR/scripts/env.sh

}

function updateEnvForNewOrg {
    if [ $# -ne 6 ]; then
        echo "Usage: updateEnv <home-dir> <repo-name> <datadir-name> <domain-name> <orderer-name> <peer-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local DATADIR=$3
    log "updating env.sh"

    sed -r -i.bak "s/PEER_DOMAINS=([[:graph:]]+)/PEER_DOMAINS=$4/" $HOME/$REPO/non-remote-org/env-org.sh
    sed -r -i.bak "s/PEER_ORGS=([[:graph:]]+)/PEER_ORGS=$6/" $HOME/$REPO/non-remote-org/env-org.sh

}

function createConnectionProfile {
    local DATADIR=$1
    source $DATADIR/scripts/connection-profile.sh $DATADIR $2
}

function createConfigMap {
    set +e
    if [ $# -ne 2 ]; then
        echo "Usage: createConfigMap <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2

    log "Creating configmap for connection-profile"

    for ORG in $PEER_ORGS; do
        kubectl apply -f $HOME/$REPO/$K8SYAML/fabric-configmap-connection-profile-$ORG.yaml
        confirmDeployments $ORG
    done
    
    set -e
}

function createAPI {
    set +e
    if [ $# -ne 2 ]; then
        echo "Usage: createAPI <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2

    log "Creating API"

    for ORG in $PEER_ORGS; do
        kubectl apply -f $HOME/$REPO/$K8SYAML/fabric-deployment-api-$ORG.yaml
        confirmDeployments $ORG
    done
    set -e
}

function createFrontend {
    set +e
    if [ $# -ne 2 ]; then
        echo "Usage: createAPI <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2

    log "Creating Frontend"

    for ORG in $PEER_ORGS; do
        kubectl apply -f $HOME/$REPO/$K8SYAML/fabric-deployment-frontend-$ORG.yaml
        confirmDeployments $ORG
    done
    set -e
}

function createConfigMapExplorer {
     set +e
    if [ $# -ne 3 ]; then
        echo "Usage: createConfigMapExplorer <repo-name> <data-dir> "
        exit 1
    fi
    local REPO=$1
    local DATADIR=$2
    source $DATADIR/scripts/configmap-explorer.sh $REPO $DATADIR $3
    sleep 10s

    log "Creating Configmap for Hyperledger explorer"

    for ORG in $PEER_ORGS; do
        kubectl apply -f $HOME/$REPO/$K8SYAML/fabric-configmap-explorer-$ORG.yaml
        confirmDeployments $ORG
    done
    set -e

}

function createExplorerDB {
    set +e
    if [ $# -ne 2 ]; then
        echo "Usage: createExplorerDB <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2

    log "Creating Hyperledger Explorer DB"

    for ORG in $PEER_ORGS; do
        kubectl apply -f $HOME/$REPO/$K8SYAML/fabric-deployment-explorerdb-$ORG.yaml
        confirmDeployments $ORG
    done
    set -e
}

function createExplorer {
    set +e
    if [ $# -ne 2 ]; then
        echo "Usage: createExplorer <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2

    log "Creating Hyperledger Explorer"

    for ORG in $PEER_ORGS; do
        kubectl apply -f $HOME/$REPO/$K8SYAML/fabric-deployment-explorer-$ORG.yaml
        confirmDeployments $ORG
    done
    set -e
}

function createPrometheusConfig {
    local REPO=$1
    local DATADIR=$2
    source $DATADIR/scripts/prometheus-config.sh $REPO $DATADIR $3

     log "Creating Configmap for Prometheus"

    for ORG in $PEER_ORGS; do
        kubectl apply -f $HOME/$REPO/$K8SYAML/fabric-configmap-prometheus-$ORG.yaml
        confirmDeployments $ORG
    done
    set -e
}

function createPrometheus {
    set +e
    if [ $# -ne 2 ]; then
        echo "Usage: createPrometheus <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2

    log "Creating Prometheus"

    for ORG in $PEER_ORGS; do
        kubectl apply -f $HOME/$REPO/$K8SYAML/fabric-deployment-prometheus-$ORG.yaml
        confirmDeployments $ORG
    done
    set -e
}

function createGrafanaConfig {
    set +e
    if [ $# -ne 2 ]; then
        echo "Usage: createGrafanaConfig <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2

    log "Creating Grafana Configmap"

    for ORG in $PEER_ORGS; do
        kubectl apply -f $HOME/$REPO/$K8SYAML/fabric-configmap-grafana-$ORG.yaml
        confirmDeployments $ORG
    done
    set -e
}


function createGrafana {
    set +e
    if [ $# -ne 2 ]; then
        echo "Usage: createGrafana <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2

    log "Creating Grafana"

    for ORG in $PEER_ORGS; do
        kubectl apply -f $HOME/$REPO/$K8SYAML/fabric-deployment-grafana-$ORG.yaml
        confirmDeployments $ORG
    done
    set -e
}


function createIngressForPayer {
    set +e
    if [ $# -ne 2 ]; then
        echo "Usage: createIngressForPayer <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2

    log "Creating Ingress for Payer Org"

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.0.4/deploy/static/provider/aws/deploy.yaml
    sleep 15s
    
    for ORG in $PEER_ORGS; do
        kubectl apply -f $HOME/$REPO/$K8SYAML/fabric-ingress-$ORG.yaml
        confirmDeployments $ORG
    done
    set -e
}

function getAdminOrg {
    peerorgs=($PEER_ORGS)
    ADMINORG=${peerorgs[0]}
}

function stopJobsFabric {
    if [ $# -ne 2 ]; then
        echo "Usage: stopJobsFabric <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Stopping Jobs on Fabric in K8s"
    set +e
    # we take a brute-force approach here and just delete all the jobs, even though not all jobs
    # run in all org namespaces. Since there is no 'set -e' in this script, it will continue
    # if there are errors
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        #kubectl delete -f $REPO/k8s/fabric-job-upgradecc-$ORG.yaml --namespace $DOMAIN
        #kubectl delete -f $REPO/k8s/fabric-job-installcc-$ORG.yaml --namespace $DOMAIN
        #kubectl delete -f $REPO/k8s/fabric-job-addorg-join-$ORG.yaml --namespace $DOMAIN
        #kubectl delete -f $REPO/k8s/fabric-job-updateconf-$ORG.yaml --namespace $DOMAIN
        #kubectl delete -f $REPO/k8s/fabric-job-signconf-$ORG.yaml --namespace $DOMAIN
        #kubectl delete -f $REPO/k8s/fabric-job-addorg-setup-$ORG.yaml --namespace $DOMAIN
        #kubectl delete -f $REPO/k8s/fabric-job-delete-org-$ORG.yaml --namespace $DOMAIN
    done

    #confirmDeploymentsStopped addorg-fabric-setup
    #confirmDeploymentsStopped fabric-sign
    #confirmDeploymentsStopped fabric-updateconf
    #confirmDeploymentsStopped addorg-fabric-join
    #confirmDeploymentsStopped fabric-installcc
    #confirmDeploymentsStopped fabric-upgradecc
    #confirmDeploymentsStopped fabric-delete-org
}


function stopChannelArtifacts {
    if [ $# -ne 2 ]; then
        echo "Usage: stopChannelArtifacts <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Stopping Fabric Channel Artifacts"
    kubectl delete -f $REPO/$K8SYAML/fabric-deployment-channel-artifacts.yaml
    confirmDeploymentsStopped channel-artifacts
}

function confirmDeploymentsStopped {
    if [ $# -eq 0 ]; then
        echo "Usage: confirmDeploymentsStopped <deployment> <org - optional>"
        exit 1
    fi
    DEPLOY=$1
    if [ $# -eq 2 ]; then
        TMPORG='healthcare-hlf'
        log "Checking whether pods have stopped for org '$TMPORG'"
        NUMPENDING=$(kubectl get po -n $TMPORG | grep $DEPLOY | awk '{print $5}' | wc -l | awk '{print $1}')
        while [ "${NUMPENDING}" != "0" ]; do
            echo "Waiting on deployments matching $DEPLOY in namespace $TMPORG to stop. Deployments pending = ${NUMPENDING}"
            NUMPENDING=$(kubectl get po -n $TMPORG | grep $DEPLOY | awk '{print $5}' | wc -l | awk '{print $1}')
            sleep 3
        done
    else
        log "Checking whether all pods have stopped"
        for ORG in $ORGS; do
            TMPORG='healthcare-hlf'
            NUMPENDING=$(kubectl get po -n $TMPORG | grep $DEPLOY | awk '{print $5}' | wc -l | awk '{print $1}')
            while [ "${NUMPENDING}" != "0" ]; do
                echo "Waiting on deployments matching $DEPLOY in namespace $TMPORG to stop. Deployments pending = ${NUMPENDING}"
                NUMPENDING=$(kubectl get po -n $TMPORG | grep $DEPLOY | awk '{print $5}' | wc -l | awk '{print $1}')
                sleep 3
            done
        done
    fi
}


function confirmJobs {
    log "Checking whether all jobs are ready"

    for TMPORG in $ORGS; do
        getDomain $TMPORG
        NUMPENDING=$(kubectl get jobs --namespace $NAMESPACE | awk '{print $3}' | grep 0 | wc -l | awk '{print $1}')
        local COUNT=1
        while [ "${NUMPENDING}" != "0" ]; do
            echo "Waiting on pending jobs in namespace '$NAMESPACE'. Jobs pending = ${NUMPENDING}"
            NUMPENDING=$(kubectl get jobs --namespace $NAMESPACE | awk '{print $3}' | grep 0 | wc -l | awk '{print $1}')
            sleep 3
            # if a job name was passed to this function, check the job status
            if [ $# -gt 0 ]; then
                COUNT=$((COUNT+1))
                if (( $COUNT % 5 == 0 )); then
                    # check for the pod status: e.g. Pods Statuses:  0 Running / 0 Succeeded / 6 Failed
                    NUMFAILED=$(kubectl describe jobs/$1 --namespace $NAMESPACE | grep "Pods Statuses" | awk '{print $9}')
                    if [ $NUMFAILED -gt 0 ]; then
                        echo "'$NUMFAILED' jobs with name '$1' have failed so far in namespace '$NAMESPACE'. After 6 failures we will exit"
                    fi
                    if [ $NUMFAILED -eq 6 ]; then
                        echo "'$NUMFAILED' jobs with name '$1' have failed in namespace '$NAMESPACE'. We will exit"
                        return 1
                    fi

                fi
            fi
        done
    done
}



function confirmDeployments {
    log "Checking whether all deployments are ready"

    #for TMPORG in $ORGS; do
        TMPORG='healthcare-hlf'
        NUMPENDING=$(kubectl get deployments -n $TMPORG | awk '{print $2}' | grep 0 | wc -l | awk '{print $1}')
        while [ "${NUMPENDING}" != "0" ]; do
            echo "Waiting on pending deployments. Deployments pending = ${NUMPENDING}"
            NUMPENDING=$(kubectl get deployments -n $TMPORG | awk '{print $2}' | grep 0 | wc -l | awk '{print $1}')
            sleep 3
        done
    #done
}



function installNodeNPM {
    sudo yum install -y gcc-c++ make 
    curl -sL https://rpm.nodesource.com/setup_14.x | sudo -E bash - 
    sudo yum install -y nodejs 
    node -v
    npm -v 

}
