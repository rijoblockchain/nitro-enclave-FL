/*
Copyright IBM Corp. All Rights Reserved.

SPDX-License-Identifier: Apache-2.0
*/

package healthcare

import (
	"fmt"
	//"encoding/base64"
	"encoding/json"
	//"strings"
	"log"
	//"crypto/sha256"
	//"hash"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	//"github.com/golang/protobuf/ptypes"
	"healthcare3.0/payer"
	//"healthcare3.0/provider"
	//"healthcare3.0/pharma"
	
)

// PropertyRegistration SmartContract provides functions for managing an registrar and users smart contracts
type Healthcare struct {
	contractapi.Contract
}

type RequestAccess struct {
	RequestID		string
	PatientID		string
	PatientName		string
	PrimaryProvider	string
	RequestedBy 	string
	RequestedAt 	string
}

// Global Model IPFS Hash
type GlobalModel struct {
	DocType				string    `json:"docType"`
	ID    				string    `json:"globalModelID"`
	IPFSHash			string 	  `json:"IPFSHash"`
	UpdatedAt			string	  `json:"updatedAt"`
}

// EncryptedGlobalWeights stored encrypted global weights that are private to provider
type EncryptedGlobalWeights struct {
	DocType					string    `json:"docType"`
	ID        				string 	  `json:"globalWeightsID"`
	EncryptedGlobalWeights	string    `json:"encryptedGlobalWeights"`
	UpdatedAt				string	  `json:"updatedAt"`

	
}

// HistoryQueryResult structure used for returning result of history query
type HistoryQueryResult struct {
	Record    *payer.PatientData    `json:"record"`
	TxId       string   		    `json:"txId"`
	Timestamp time.Time 			`json:"timestamp"`
	IsDelete  bool     			    `json:"isDelete"`
}

// Initializes all the smart contracts
func (healthcare *Healthcare) InitHealthcare(ctx contractapi.TransactionContextInterface) error {
	fmt.Println("Healthcare Smart contract is initiated")
	return nil
}

func (healthcare *Healthcare) SaveGlobalModel(ctx contractapi.TransactionContextInterface)  error {

	dt := time.Now()
	formattedTime := dt.Format("01-02-2006 15:04:05")

	// Get new patient details from transient map
	transientMap, err := ctx.GetStub().GetTransient()
	if err != nil {
		return fmt.Errorf("error getting transient: %v", err)
	}
	
	
	// Global models are private, therefore they get passed in transient field, instead of func args
	transientGlobalModelJSON, ok := transientMap["global_model"]
	if !ok {
		//log error to stdout
		return fmt.Errorf("global model not found in the transient map input")
	}

	var globalModelInput GlobalModel

	err = json.Unmarshal(transientGlobalModelJSON, &globalModelInput)
	if err != nil {
		return fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	// Set the updated time
	globalModelInput.UpdatedAt = formattedTime

	globalModelJSONasBytes, err := json.Marshal(globalModelInput)
	if err != nil {
		return fmt.Errorf("failed to marshal global model into JSON: %v", err)
	}

	err = ctx.GetStub().PutState(globalModelInput.ID, globalModelJSONasBytes)
	if err != nil {
		return fmt.Errorf("failed to put global model: %v", err)
	}	
	
	return nil
}

func (healthcare *Healthcare) SaveGlobalWeights(ctx contractapi.TransactionContextInterface) error {
	
	dt := time.Now()
	formattedTime := dt.Format("01-02-2006 15:04:05")

	// Get new patient details from transient map
	transientMap, err := ctx.GetStub().GetTransient()
	if err != nil {
		return fmt.Errorf("error getting transient: %v", err)
	}


	// Patient records are private, therefore they get passed in transient field, instead of func args
	transientGlobalWeightsJSON, ok := transientMap["global_weights"]
	if !ok {
		//log error to stdout
		return fmt.Errorf("global_weights not found in the transient map input")
	}
	

	var globalWeightsInput EncryptedGlobalWeights

	err = json.Unmarshal(transientGlobalWeightsJSON, &globalWeightsInput)
	if err != nil {
		return fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	// Check if patient already exists
	globalWeightsAsBytes, err := ctx.GetStub().GetPrivateData("PayerProvider1MSPCollection", globalWeightsInput.ID)
	if err != nil {
		return fmt.Errorf("failed to get global weights: %v", err)
	} else if globalWeightsAsBytes != nil {
		fmt.Println("Global Weights ID already exists: " + globalWeightsInput.ID)
		return fmt.Errorf("this Global Weights ID already exists: " + globalWeightsInput.ID)
	}
	

	globalWeightsInput.UpdatedAt = formattedTime

	globalWeightsJSONasBytes, err := json.Marshal(globalWeightsInput)
	if err != nil {
		return fmt.Errorf("failed to marshal global weights into JSON: %v", err)
	}

	// Save global weights to private data collection of payer and provider
	// Typical logger, logs to stdout/file in the fabric managed docker container, running this chaincode
	// Look for container name like dev-peer0.provider1.org-{chaincodename_version}-xyz
	log.Printf("SaveGlobalWeights Put: collection %v, ID %v", "PayerProvider1MSPCollection", globalWeightsInput.ID)

	err = ctx.GetStub().PutPrivateData("PayerProvider1MSPCollection", globalWeightsInput.ID, globalWeightsJSONasBytes)
	if err != nil {
		return fmt.Errorf("failed to put global weights into private data collecton: %v", err)
	}

	return nil
}

// ReadGlobalWeightsInfo reads the encrypted updated global weights from collection
func (healthcare *Healthcare) ReadGlobalWeightsInfo(ctx contractapi.TransactionContextInterface, globalWeightsID string) (*EncryptedGlobalWeights, error) {


	globalWeightsJSON, err := ctx.GetStub().GetPrivateData("PayerProvider1MSPCollection", globalWeightsID) //get the global weights from chaincode state
	if err != nil {
		return nil, fmt.Errorf("failed to read global weights: %v", err)
	}

	//No Global weights found, return empty response
	if globalWeightsJSON == nil {
		log.Printf("%v does not exist in collection %v", globalWeightsID, "PayerProvider1MSPCollection")
		return nil, nil
	}

	var globalWeights *EncryptedGlobalWeights
	err = json.Unmarshal(globalWeightsJSON, &globalWeights)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	return globalWeights, nil
}



// ReadGlobalModelHash reads the information from collection
func (healthcare *Healthcare) ReadGlobalModelHash(ctx contractapi.TransactionContextInterface, globalModelID string) (*GlobalModel, error) {
	

	log.Printf("Read Public Ledger ACL: ID %v", globalModelID)
	globalModelJSON, err := ctx.GetStub().GetState(globalModelID) //get the global model details from chaincode state
	if err != nil {
		return nil, fmt.Errorf("failed to read global model ipfs hash: %v", err)
	}

	//No Patient found, return empty response
	if globalModelJSON == nil {
		log.Printf("%v does not exist in state ledger", globalModelID)
		return nil, nil
	}

	var globalModel GlobalModel
	err = json.Unmarshal(globalModelJSON, &globalModel)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	return &globalModel, nil


}

