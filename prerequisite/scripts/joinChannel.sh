#!/bin/bash

set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh

peer channel join -b $CHANNEL_BLOCK_FILE

