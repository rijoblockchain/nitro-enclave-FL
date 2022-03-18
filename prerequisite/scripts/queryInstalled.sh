#!/bin/bash

set -e

peer lifecycle chaincode queryinstalled

#PACKAGE_ID=$(awk -F'Chaincode code package identifier: ' '{print $2}' /opt/share/chaincode/basic/packaging/log.txt)

