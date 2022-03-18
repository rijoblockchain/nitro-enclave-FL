/*
Copyright IBM Corp. All Rights Reserved.

SPDX-License-Identifier: Apache-2.0
*/

package pharma

import (
	//"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"
	//"strings"
	"log"
	"crypto/sha256"
	"crypto/rand"
	"hash"

	//"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	 //"github.com/hyperledger/fabric-chaincode-go/pkg/statebased"
 // pb "github.com/hyperledger/fabric-protos-go/peer"
 	"healthcare3.0/payer"
)

// SmartContract for Pharma
type Pharma struct {
	contractapi.Contract
}

type OrderRequest struct {
	RequestID			string
	PatientID			string
	PatientName			string
	Prescriber			string
	Medicines		  []string	
	Status				string
	CreatedAt			string
	Pharma				string
}

// Create a new request asset for a new medicine order
func (pharma *Pharma) OrderMedicine(ctx contractapi.TransactionContextInterface, patientID string, patientName string, pharmaName string)  (string, error) {

	dt := time.Now()
	formattedTime := dt.Format("01-02-2006 15:04:05")
	patientACL, err := readPatientACL(ctx, patientID)

	patientData, err := readPatient(ctx, patientID)

	var PayerProviderCollection = "Payer"+patientACL.PrimaryProvider+"Collection"
	r1, _ := rand.Prime(rand.Reader, 16)
	r2, _ := rand.Prime(rand.Reader, 16)

	orderRequestCompositeKey := "ORDER"+ r1.String()+ r2.String()
	
	newOrderRequest := OrderRequest {
		RequestID:			orderRequestCompositeKey,
		PatientID:			patientID,
		PatientName:		patientName,
		Prescriber:			patientData.PatientVitals.PrescriptionUpdatedBy,
		Medicines:		  	patientData.PatientVitals.Prescription,
		Status:				"Ordered",
		CreatedAt:			formattedTime,
		Pharma:				pharmaName,
	}

	marshaledOrderRequest, err := json.Marshal(newOrderRequest)
	if err != nil {
		return "", fmt.Errorf("failed to marshal order request into JSON: %v", err)
	}

	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, orderRequestCompositeKey, marshaledOrderRequest)
	if err != nil {
		return "", fmt.Errorf("failed to put order request: %v", err)
	}

	PayerProviderCollection = "Payer"+pharmaName+"Collection"

	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, orderRequestCompositeKey, marshaledOrderRequest)
	if err != nil {
		return "", fmt.Errorf("failed to put order request: %v", err)
	}

	return orderRequestCompositeKey, nil

}

func (pharma *Pharma) MedicineDelivered(ctx contractapi.TransactionContextInterface, patientID string, orderRequestID string)  error {
	

	clientMSPID, err:= ctx.GetClientIdentity().GetMSPID()

	orderRequest, err := readOrderRequest(ctx, patientID, orderRequestID)

	orderRequest.Status = "Delivered"

	patientACL, err := readPatientACL(ctx, patientID)

	var PayerProviderCollection = "Payer"+patientACL.PrimaryProvider+"Collection"

	marshaledOrderRequest, err := json.Marshal(orderRequest)
	if err != nil {
		return fmt.Errorf("failed to marshal order request into JSON: %v", err)
	}

	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, orderRequestID, marshaledOrderRequest)
	if err != nil {
		return fmt.Errorf("failed to put order request: %v", err)
	}

	PayerProviderCollection = "Payer"+clientMSPID+"Collection"

	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, orderRequestID, marshaledOrderRequest)
	if err != nil {
		return fmt.Errorf("failed to put order request: %v", err)
	}

	return nil
}

// ReadPatient reads the information from collection
func readPatient(ctx contractapi.TransactionContextInterface, patientID string) (*payer.PatientData, error) {

	var patient *payer.PatientData
	
	clientMSPID, _:= ctx.GetClientIdentity().GetMSPID()

	clientID := CreateHashMultiple([]byte(clientMSPID), []byte("123"))
	hashClientMSPID := base64.URLEncoding.EncodeToString(clientID)

	patientACL, err := readPatientACL(ctx, patientID)

	_, providerHasAccess := Find(patientACL.HashProviderAccess, hashClientMSPID)

	log.Println(hashClientMSPID)
	if !providerHasAccess {
        return nil, fmt.Errorf("%v is not allowed to read patient details", clientMSPID)
    }

	var PayerProviderMSPCollection = "Payer"+patientACL.PrimaryProvider+"Collection"
	//log.Printf("ReadPatient: collection %v, ID %v", "PayerMSPCollection", patientID)
	patientJSON, err := ctx.GetStub().GetPrivateData(PayerProviderMSPCollection, patientID) //get the patient details from chaincode state
	if err != nil {
		return nil, fmt.Errorf("failed to read patient: %v", err)
	}

	//No Patient found, return empty response
	if patientJSON == nil {
		//log.Printf("%v does not exist in collection %v", patientID, "PayerMSPCollection")
		return nil, fmt.Errorf("%v does not exist in collection %v", patientID, PayerProviderMSPCollection)
	}

	err = json.Unmarshal(patientJSON, &patient)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	
	return patient, nil

}


// ReadPatientACL reads the information from state ledger
func readPatientACL(ctx contractapi.TransactionContextInterface, patientID string) (*payer.PatientACL, error) {


	ID := CreateHashMultiple([]byte(patientID), []byte("123"))
	hashID := base64.URLEncoding.EncodeToString(ID)	

	log.Printf("Read Public Ledger ACL: ID %v", hashID)
	patientACLJSON, err := ctx.GetStub().GetState(hashID) //get the patient details from chaincode state
	if err != nil {
		return nil, fmt.Errorf("failed to read patient: %v", err)
	}

	//No Patient found, return empty response
	if patientACLJSON == nil {
		log.Printf("%v does not exist in state ledger", patientID)
		return nil, nil
	}

	var patientACL payer.PatientACL
	err = json.Unmarshal(patientACLJSON, &patientACL)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	return &patientACL, nil

}


// ReadOrderRequestPatient reads the order details from collection
func readOrderRequest(ctx contractapi.TransactionContextInterface, patientID string, orderRequestID string) (*OrderRequest, error) {
	var PayerProviderCollection string
	clientMSPID, _:= ctx.GetClientIdentity().GetMSPID()

	PayerProviderCollection = "Payer"+clientMSPID+"Collection"
	
	orderRequestJSON, err := ctx.GetStub().GetPrivateData(PayerProviderCollection, orderRequestID) //get the order details from chaincode state
	if err != nil {
		return nil, fmt.Errorf("failed to read order details: %v", err)
	}

	//No Request for new order found, return empty response
	if orderRequestJSON == nil {
		//log.Printf("%v does not exist in collection %v", patientID, "PayerMSPCollection")
		return nil, fmt.Errorf("%v does not exist in collection %v", orderRequestID, PayerProviderCollection)
	}

	var orderRequest OrderRequest
	err = json.Unmarshal(orderRequestJSON, &orderRequest)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	return &orderRequest, nil

}


func Find(slice []string, val string) (int, bool) {
    for i, item := range slice {
        if item == val {
            return i, true
        }
    }
    return -1, false
}

//CreateHash method
func CreateHash(byteStr []byte) []byte {
	var hashVal hash.Hash
	hashVal = sha256.New()
	hashVal.Write(byteStr)

	var bytes []byte

	bytes = hashVal.Sum(nil)
	return bytes
}

// Create hash for Multiple Values method
func CreateHashMultiple(byteStr1 []byte, byteStr2 []byte) []byte {
	return xor(CreateHash(byteStr1), CreateHash(byteStr2))
  }

// XOR Method

func xor(byteStr1 []byte, byteStr2 []byte) []byte {
	var xorbytes []byte
	xorbytes = make([]byte, len(byteStr1))
	var i int
	for i = 0; i< len(byteStr1); i++ {
		xorbytes[i] = byteStr1[i] ^ byteStr2[i]
	}
	return xorbytes
}



