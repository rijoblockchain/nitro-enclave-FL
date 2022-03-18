/*
SPDX-License-Identifier: Apache-2.0
*/

package main

import (
	"log"
	//"fmt"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	//"github.com/hyperledger/fabric-chaincode-go/shim"
	"healthcare3.0/healthcare"
	
	
)

func main() {
	hlfChaincode, err := contractapi.NewChaincode(&healthcare.Healthcare{})
	if err != nil {
		log.Panicf("Error creating patient-private-data chaincode: %v", err)
	}

	if err := hlfChaincode.Start(); err != nil {
		log.Panicf("Error starting patient-private-data chaincode: %v", err)
	}

}
