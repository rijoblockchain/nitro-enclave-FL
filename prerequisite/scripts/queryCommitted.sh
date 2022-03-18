#!/bin/bash


function main {
    peer lifecycle chaincode querycommitted -C $CHANNEL_NAME
}

set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh 


main