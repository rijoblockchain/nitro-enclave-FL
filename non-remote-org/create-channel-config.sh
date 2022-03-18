#!/usr/bin/env bash




function main {
    local HOME=$1
    local REPO=$2
    NEW_ORG=$3
    log "Step3: Creating channel config for new org $NEW_ORG ..."
    # Stop all jobs. Previous jobs would have either added/removed an org 
    #stopJobsFabric $HOME $REPO

    # create a new configtx.yaml that includes the new org
    # updateChannelArtifacts $HOME $REPO

    #Now we need to create the channel config to add the new org
    set +e
    startaddorgFabric $NEW_ORG
    # SIGNCONFIG=$?
    # if [ $SIGNCONFIG -eq 1 ]; then
    #     log "Step3: Job fabric-job-addorg-setup-$ORG.yaml did not achieve a successful completion - check the logs; exiting"
    #     return 1
    # fi
    log "Step3: Creating channel config for new org $NEW_ORG complete"



}

function startaddorgFabric {
    log "Starting addorg Fabric in K8s"
    NEW_ORG=$1
    COUNT=1
    getAdminOrg
    getDomain $ADMINORG
    kubectl exec --stdin --tty  $(kubectl get pods -n $NAMESPACE |grep cli-peer$COUNT-$ADMINORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/addorg-fabric-setup.sh $ADMINORG $NEW_ORG
    # kubectl apply -f $REPO/k8s-$ADMINORG/fabric-job-addorg-setup-$ADMINORG.yaml --namespace $NAMESPACE
    # confirmJobs "addorg-fabric-setup"
    # if [ $? -eq 1 ]; then
    #     log "Step3: Job fabric-job-addorg-setup-$ADMINORG.yaml failed; exiting"
    #     exit 1
    # fi

    # set +e
    # #domain is overwritten by confirmJobs, so we look it up again
    # getDomain $ADMINORG
    # # check whether the setup of the new org has completed
    # for i in {1..10}; do
    #     if kubectl logs jobs/addorg-fabric-setup --namespace $NAMESPACE --tail=10 | grep -q "Congratulations! The config file for the new org"; then
    #         log "Step3: New org configuration created by fabric-job-addorg-setup-$ADMINORG.yaml"
    #         return 0
    #     elif kubectl logs jobs/addorg-fabric-setup --namespace $NAMESPACE --tail=10 | grep -q "Org '$NEW_ORG' already exists in the channel config"; then
    #         log "Step3: Org '$NEW_ORG' already exists in the channel config - I will cleanup but will not attempt to update the channel config"
    #         return 99
    #     else
    #         log "Step3: Waiting for fabric-job-addorg-setup-$ADMINORG.yaml to complete"
    #         sleep 5
    #     fi
    # done
    #return 1
}



# cat > ${DATADIR}/organizations/fabric-ca/{$NEW_ORG}RCA/updateorg << EOF
# ${NEW_ORG}
# EOF

HOME=$1
REPO=$2
DATADIR=$3
NEW_ORG=$4
SCRIPTS=$DATADIR/scripts
source $HOME/$REPO/fabric-main/gen-env-file.sh
genNewEnvAddOrg $NEW_ORG $SCRIPTS
sudo cp $SCRIPTS/envaddorgs.sh $SCRIPTS/env.sh
source $SCRIPTS/env.sh
source $HOME/$REPO/fabric-main/util-prep.sh
source $HOME/$REPO/fabric-main/utilities.sh

main $HOME $REPO $NEW_ORG