#!/usr/bin/env bash

set -e

function copyScripts {
    if [ $# -ne 3 ]; then
        echo "Usage: copyScripts <home-dir> <repo-name> <data-dir - probably something like /opt/share/>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local DATA=$3
    echo "Copying scripts folder from $REPO to $DATA"
    cd $HOME
    sudo cp -R $HOME/$REPO/prerequisite/* $DATA/
    #sudo chmod +x $DATA/scripts -R
    sudo chmod 777 $DATA/* -R
    #sudo chown 1003:1003 $DATA/* -R
    

}

function makeDirs {
    if [ $# -ne 1 ]; then
        echo "Usage: makeDirs <data-dir - probably something like /opt/share//>"
        echo "input args are '$@'"
        exit 1
    fi
    local DATA=$1
    echo "Making directory at $DATA"
    cd $DATA
    
    mkdir -p organizations
    cp -R fabric-ca organizations
    
    #sudo chown 1003:1003 organizations -R
    sudo rm -rf fabric-ca  
}

function genTemplates {
    if [ $# -ne 2 ]; then
        echo "Usage: genTemplates <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    echo "Generating K8s YAML deployment files"
    cd $HOME/$REPO/fabric-main
    ./gen-fabric.sh
}

#the env.sh in $SCRIPTS will have been updated with the DNS of the various endpoints, such as ORDERER and
#ANCHOR PEER. We need to merge the contents of env-org.sh into $SCRIPTS/env.sh in order to retain
#these DNS endpoints as they are used by the remote peer
function mergeEnv {
    if [ $# -ne 4 ]; then
        echo "Usage: mergeEnv <home-dir> <repo-name> <data-dir - probably something like /opt/share> <filename - env file to be merged into main env.sh>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local DATA=$3
    local FILE=$4
    echo "Merging the ENV files"
    cd $HOME/$REPO
    start='^##--BEGIN REPLACE CONTENTS--##$'
    end='^##--END REPLACE CONTENTS--##$'
    newfile=`sed -e "/$start/,/$end/{ /$start/{p; r $FILE
        }; /$end/p; d }" $DATA/scripts/env.sh`
    sudo chown ec2-user $DATA/scripts/env.sh
    echo "$newfile" > $DATA/scripts/env.sh
    cp $DATA/scripts/env.sh prerequisite/scripts/env.sh
}