/*
Copyright IBM Corp. All Rights Reserved.

SPDX-License-Identifier: Apache-2.0
*/

package provider

import (
	//"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"
	//"strings"
	"log"
	"crypto/sha256"
	//"crypto/rand"
	"hash"

	//"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	 //"github.com/hyperledger/fabric-chaincode-go/pkg/statebased"
 // pb "github.com/hyperledger/fabric-protos-go/peer"
 	"healthcare3.0/payer"
)

// SmartContract for Provider
type Provider struct {
	contractapi.Contract
}

/*type LabRequest struct {
	RequestID			string
	PatientID			string
	PatientName			string
	PrimaryProvider		string
	LabTest				string
	Status				string
	CreatedBy			string
	CreatedAt			string
	Lab					string
}*/

// Create a new request asset for a new patient
func (provider *Provider) RequestNewPatient(ctx contractapi.TransactionContextInterface, patientInfo []byte)  error {
	dt := time.Now()
	formattedTime := dt.Format("01-02-2006 15:04:05")
	clientMSPID, err:= ctx.GetClientIdentity().GetMSPID()

	var newRequest payer.PatientPrivateDetails
	var PayerProviderCollection = "Payer"+clientMSPID+"Collection"

	err = json.Unmarshal(patientInfo, &newRequest)
	newRequest.ProviderAccess = []string{"PayerMSP"}
	newRequest.CreatedAt = formattedTime
	newRequest.CreatedBy = clientMSPID
	newRequest.UpdatedAt = formattedTime
	newRequest.UpdatedBy = clientMSPID
	
	var requestDetails *payer.RequestPatient
	requestDetails = &payer.RequestPatient{
		PatientPrivateData: newRequest,
		Approved:	"No",

	}

	requestCompositeKey, _ := ctx.GetStub().CreateCompositeKey("request-patient.hlf-network.com", []string{newRequest.ID, newRequest.Name})
	marshaledRequest, err := json.Marshal(requestDetails)
	if err != nil {
		return fmt.Errorf("failed to marshal patient request into JSON: %v", err)
	}
	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, requestCompositeKey, marshaledRequest)
	if err != nil {
		return fmt.Errorf("failed to put patient request: %v", err)
	}

	requestID := CreateHashMultiple([]byte(requestCompositeKey), []byte("123"))
	hashRequestID := base64.URLEncoding.EncodeToString(requestID)

	var hashProviderAccess []string
	providerAccess := CreateHashMultiple([]byte("PayerMSP"), []byte("123"))
	hashProviderAccess = []string{base64.URLEncoding.EncodeToString(providerAccess)}
	providerAccess = CreateHashMultiple([]byte(clientMSPID), []byte("123"))
	hashProviderAccess = append(hashProviderAccess, base64.URLEncoding.EncodeToString(providerAccess))

	// Save request new patient ACL details to public state ledger visible to all organization
	var requestPatientACLDetails *payer.RequestPatientACL
	requestPatientACLDetails = &payer.RequestPatientACL{
		RequestID:		  	requestCompositeKey,
		HashRequestID:		hashRequestID,	
		CreatedBy:			clientMSPID,  		
		ProviderAccess:		[]string{"PayerMSP", clientMSPID},
		HashProviderAccess:	hashProviderAccess,
	}

	requestPatientACLDetailsAsBytes, err := json.Marshal(requestPatientACLDetails) // marshal request patient ACL details to JSON
	if err != nil {
		return fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	// Put patient ACL into public state ledger
	log.Printf("Put ACL: ID %v", hashRequestID)
	err = ctx.GetStub().PutState(hashRequestID, requestPatientACLDetailsAsBytes)
	if err != nil {
		return fmt.Errorf("failed to put patient ACL: %v", err)
	}

	return nil

}

// Create a new request asset for a lab test
/*func (provider *Provider) RequestForLabTest(ctx contractapi.TransactionContextInterface, patientID string, patientName string, labTest string)  (string, error) {
	dt := time.Now()
	formattedTime := dt.Format("01-02-2006 15:04:05")
	
	clientMSPID, err:= ctx.GetClientIdentity().GetMSPID()
	
	clientID := CreateHashMultiple([]byte(clientMSPID), []byte("123"))
	hashClientMSPID := base64.URLEncoding.EncodeToString(clientID)

	patientACL, err := readPatientACL(ctx, patientID)

	_, providerHasAccess := Find(patientACL.HashProviderAccess, hashClientMSPID)

	log.Println(hashClientMSPID)
	if !providerHasAccess {
        return "", fmt.Errorf("%v is not allowed to read patient details", clientMSPID)
    }

	var PayerProviderCollection = "Payer"+patientACL.PrimaryProvider+"Collection"
	r1, _ := rand.Prime(rand.Reader, 16)
	r2, _ := rand.Prime(rand.Reader, 16)

	labRequestCompositeKey := "labTest"+ r1.String()+ r2.String()//ctx.GetStub().CreateCompositeKey("labtest", []string{r1.String(), r2.String()})
	
	newLabRequest := &LabRequest {
		RequestID:			labRequestCompositeKey,
		PatientID:			patientID,
		PatientName:		patientName,
		PrimaryProvider:	patientACL.PrimaryProvider,
		LabTest:			labTest,
		Status:				"In Process",
		CreatedBy:			clientMSPID,
		CreatedAt:			formattedTime,
		Lab:				"Not Assigned",
	}

	marshaledLabRequest, err := json.Marshal(newLabRequest)
	if err != nil {
		return "", fmt.Errorf("failed to marshal lab request into JSON: %v", err)
	}
	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, labRequestCompositeKey, marshaledLabRequest)
	if err != nil {
		return "", fmt.Errorf("failed to put lab request: %v", err)
	}

	
	// Save request new lab request public details to public state ledger visible to all organization

	labRequestPublicDetails := &LabRequest{
		RequestID:			labRequestCompositeKey,
		PrimaryProvider:	patientACL.PrimaryProvider,	
		LabTest:			labTest,
		Status:				"In Process",
		CreatedBy:			clientMSPID,
		CreatedAt:			formattedTime,
	}

	labRequestPublicDetailsAsBytes, err := json.Marshal(labRequestPublicDetails) // marshal lab request details to JSON
	if err != nil {
		return "", fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	// Put lab test request into public state ledger
	err = ctx.GetStub().PutState(labRequestCompositeKey, labRequestPublicDetailsAsBytes)
	if err != nil {
		return "", fmt.Errorf("failed to put lab test request: %v", err)
	}

	return labRequestCompositeKey, nil

}*/



// ReadRequestPatient reads the information from collection
func (provider *Provider) ReadRequestPatient(ctx contractapi.TransactionContextInterface, patientID string, patientName string) (*payer.RequestPatient, error) {
	var PayerProviderCollection string
	clientMSPID, _:= ctx.GetClientIdentity().GetMSPID()

	clientID := CreateHashMultiple([]byte(clientMSPID), []byte("123"))
	hashClientMSPID := base64.URLEncoding.EncodeToString(clientID)

	requestCompositeKey, _ := ctx.GetStub().CreateCompositeKey("request-patient.hlf-network.com", []string{patientID, patientName})

	requestPatientACL, err := provider.ReadRequestPatientACL(ctx, patientID, patientName)

	_, providerHasAccess := Find(requestPatientACL.HashProviderAccess, hashClientMSPID)

	log.Println(hashClientMSPID)
	if !providerHasAccess {
        return nil, fmt.Errorf("%v is not allowed to read request details", clientMSPID)
    }

	PayerProviderCollection = "Payer"+requestPatientACL.CreatedBy+"Collection"

	requestPatientJSON, err := ctx.GetStub().GetPrivateData(PayerProviderCollection, requestCompositeKey) //get the patient details from chaincode state
	if err != nil {
		return nil, fmt.Errorf("failed to read patient: %v", err)
	}

	//No Request for new Patient found, return empty response
	if requestPatientJSON == nil {
		//log.Printf("%v does not exist in collection %v", patientID, "PayerMSPCollection")
		return nil, fmt.Errorf("%v does not exist in collection %v", requestCompositeKey, PayerProviderCollection)
	}

	var requestPatient *payer.RequestPatient
	err = json.Unmarshal(requestPatientJSON, &requestPatient)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	return requestPatient, nil

}

// ReadRequestPatientACL reads the request patient information from state ledger
func (provider *Provider) ReadRequestPatientACL(ctx contractapi.TransactionContextInterface, patientID string, patientName string) (*payer.RequestPatientACL, error) {

	requestCompositeKey, _ := ctx.GetStub().CreateCompositeKey("request-patient.hlf-network.com", []string{patientID, patientName})

	requestID := CreateHashMultiple([]byte(requestCompositeKey), []byte("123"))
	hashRequestID := base64.URLEncoding.EncodeToString(requestID)	

	log.Printf("Read Public Ledger ACL: ID %v", hashRequestID)
	requestPatientACLJSON, err := ctx.GetStub().GetState(hashRequestID) //get the request patient details from chaincode state
	if err != nil {
		return nil, fmt.Errorf("failed to read patient: %v", err)
	}

	//No Request found, return empty response
	if requestPatientACLJSON == nil {
		log.Printf("%v does not exist in state ledger", requestCompositeKey)
		return nil, nil
	}

	var requestPatientACL *payer.RequestPatientACL
	err = json.Unmarshal(requestPatientACLJSON, &requestPatientACL)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	return requestPatientACL, nil

}

// ReadPatient reads the information from collection
func readPatient(ctx contractapi.TransactionContextInterface, patientID string) (*payer.PatientPrivateDetails, error) {

	var patient *payer.PatientPrivateDetails
	
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

/*func (provider *Provider) ReadLabTestRequestState(ctx contractapi.TransactionContextInterface, labtest string) (*LabRequest, error) {
	
	labRequestJSON, err := ctx.GetStub().GetState(labtest) //get the lab request details from chaincode state
	if err != nil {
		return nil, fmt.Errorf("failed to read patient: %v", err)
	}

	//No Patient found, return empty response
	if labRequestJSON == nil {
		log.Printf("%v does not exist in lab request ledger", labtest)
		return nil, nil
	}

	var labRequest LabRequest
	err = json.Unmarshal(labRequestJSON, &labRequest)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	return &labRequest, nil
}*/

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
