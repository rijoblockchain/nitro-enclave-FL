#!/usr/bin/env bash


EFSSERVER=fs-0d7b6ad3edd0882a2.efs.us-east-1.amazonaws.com
REPO=healthcare-hlf-k8
source $HOME/$REPO/fabric-main/gen-fabric-functions.sh
DATA=/opt/share/efs
#DATA=/opt/share

function main {
    log "Beginning creation of Hyperledger Fabric Kubernetes YAML files..."
    cd $HOME/$REPO
    mkdir -p $K8SYAML
    genFabricOrgs 
    genNamespaces
    genPVC
    genRCA
    # #genICA
    genRegisterOrderer
    genRegisterPeers
    genChannelArtifacts
    genOrderer
    genBuilderConfig
    genCLIs
    genPeers
    genCCDeploy
    genConfigMap
    genAPI
    # genFrontend
    # genExplorerDB
    # genExplorer
    # genPrometheus
    # genGrafanaConfig
    # genGrafana
    #genIngressForPayer
    
    #log "Creation of Hyperledger Fabric Kubernetes YAML files complete"
}


main

