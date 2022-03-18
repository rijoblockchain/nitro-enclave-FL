#!/bin/bash

set -e

cd /opt/gopath/src/github.com/chaincode/basic/packaging

peer lifecycle chaincode install basic-org1.tgz >&log.txt
