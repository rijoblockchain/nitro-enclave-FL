#!/usr/bin/env bash

# this script updates the channel config signed in Step 4.

function main {
    NEW_ORG=$1
    file=$DATADIR/organizations/fabric-ca/$NEW_ORG/updateorg
    if [ -f "$file" ]; then
       NEW_ORG=$(cat $file)
       echo "File '$file' exists - new org is '$NEW_ORG'"
    else
       echo "File '$file' does not exist - cannot determine new org. Exiting..."
       break
    fi

    log "Step4: Signing channel config for new org $NEW_ORG ..."
    #Now we need to sign the channel config to add the new org
    set +e
    getAdminOrg
    getDomain $ADMINORG
    kubectl exec --stdin --tty  $(kubectl get pods -n $NAMESPACE |grep cli-peer$COUNT-$ADMINORG|awk '{print $1}') --namespace $NAMESPACE -- /bin/bash  ./scripts/update-org-config.sh $ADMINORG $NEW_ORG

}

HOME=$1
REPO=$2
DATADIR=/opt/share/
SCRIPTS=$DATADIR/scripts
source $SCRIPTS/env.sh
source $HOME/$REPO/fabric-main/utilities.sh
main $3