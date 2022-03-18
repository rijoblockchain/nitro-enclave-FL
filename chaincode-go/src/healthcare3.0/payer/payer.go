/*
Copyright IBM Corp. All Rights Reserved.

SPDX-License-Identifier: Apache-2.0
*/

package payer

import (
	//"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"
	//"strings"
	"log"
	"crypto/sha256"
	"hash"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	 "github.com/hyperledger/fabric-chaincode-go/pkg/statebased"
 // pb "github.com/hyperledger/fabric-protos-go/peer"
)

// SmartContract for Payer
type Payer struct {
	contractapi.Contract
}


// Patient describes encrypted patient ID and access permission to providers that are visible to all organizations
type PatientACL struct {
	DocType				string    `json:"docType"`
	ID    				string    `json:"patientID"`
	HashID				string 	  `json:"hashID"`
	PrimaryProvider 	string    `json:"primaryProvider"`
	HashPrimaryProvider	string    `json:"hashPrimaryProvider"`
	ProviderAccess		[]string  `json:"providerAccess"`
	HashProviderAccess	[]string  `json:"hashProviderAccess"`
	UpdatedAt			string	  `json:"updatedAt"`
}

// PatientPrivateDetails describes patient records that are private to provider
type PatientPrivateDetails struct {
	DocType				string    `json:"docType"`
	ID        			string 	  `json:"patientID"`
	Name	  			string 	  `json:"name"`
	Phone	  			string	  `json:"phone"`
	Email	  			string 	  `json:"email"`
	Gender 				string	  `json:"gender"`
	DOB					string	  `json:"dob"`
	ProviderAccess		[]string  `json:"providerAccess"`
	PrimaryProvider 	string 	  `json:"primaryProvider"`
	CreatedBy			string	  `json:"createdBy"`
	CreatedAt			string	  `json:"createdAt"`
	UpdatedBy			string 	  `json:"updatedBy"`
	UpdatedAt			string	  `json:"updatedAt"`
}

type PatientVitals struct {
	BloodSugar 	  			float32	 `json:"bloodSugar"`
	Triglycerides 	  		float32	 `json:"triglycerides"`
	HeartRate				float32  `json:"heartRate"`
	VitalsUpdatedBy			string 	 `json:"vitalsUpdatedBy"`
	VitalsUpdatedAt			string   `json:"vitalsUpdatedAt"`
	//LabRequestID			string	 `json:"labRequestID"`
	RecentLabTest			string	 `json:"recentLabTest"`
	Comments				string 	 `json:"comments"`
	Prescription	  	  []string 	 `json:"prescription"`
	PrescriptionUpdatedBy	string 	 `json:"prescriptionUpdatedBy"`
	PrescriptionUpdatedAt	string   `json:"prescriptionUpdatedAt"`
}


type PatientData struct {
	PatientPrivateDetails	PatientPrivateDetails
	PatientVitals			PatientVitals
}

type RequestPatient struct {
	PatientPrivateData 		PatientPrivateDetails 
	Approved				string	`json:"approved"`
}

type RequestPatientACL struct {
	RequestID		  	string		`json:"requestID"`
	HashRequestID	  	string		`json:"hashRequestID"`
	CreatedBy			string		`json:"createdBy"`
	ProviderAccess		[]string 	`json:"providerAccess"`
	HashProviderAccess	[]string  	`json:"hashProviderAccess"`
}

func (payer *Payer) InitPayer(ctx contractapi.TransactionContextInterface)  error {
	fmt.Println("Payer Smart contract is initiated")
	clientMSPID, _:= ctx.GetClientIdentity().GetMSPID()
	log.Printf("ClientMSPID is: %v", clientMSPID)
	return nil

}

func (payer *Payer) CreatePatient(ctx contractapi.TransactionContextInterface, transientPatientJSON []byte) error {
	
	dt := time.Now()
	formattedTime := dt.Format("01-02-2006 15:04:05")

	clientMSPID, err:= ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("failed getting the client's MSPID: %v", err)
	}
	

	type patientTransientInput struct {
		DocType				string 	  `json:"docType"`
		ID    				string 	  `json:"patientID"`
		HashID				string 	  `json:"hashID"`
		PrimaryProvider 	string 	  `json:"primaryProvider"`
		ProviderAccess 		[]string  `json:"providerAccess"`
		HashProviderAccess	[]string  `json:"hashProviderAccess"`
		Name				string 	  `json:"name"`
		Phone				string	  `json:"phone"`
		Email				string 	  `json:"email"`
		Gender 				string	  `json:"gender"`
		DOB					string	  `json:"dob"`
		CreatedBy			string	  `json:"createdBy"`
		CreatedAt			string 	  `json:"createdAt"`
		UpdatedBy			string	  `json:"updatedBy"`
		UpdatedAt			string    `json:"updatedAt"`
	}

	var patientInput patientTransientInput

	err = json.Unmarshal(transientPatientJSON, &patientInput)
	if err != nil {
		return fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	if len(patientInput.DocType) == 0 {
		return fmt.Errorf("DocType field must be a non-empty string")
	}
	if len(patientInput.ID) == 0 {
		return fmt.Errorf("Patient ID field must be a non-empty string")
	}
	/*if len(patientInput.PrimaryProvider) == 0 {
		return fmt.Errorf("Patient primary provider field must be a non-empty string")
	}*/
	if len(patientInput.Name) == 0 {
		return fmt.Errorf("Name field must be a non-empty string")
	}
	if len(patientInput.Phone) == 0 {
		return fmt.Errorf("Phone field must be a non-empty string")
	}
	if len(patientInput.Email) == 0 {
		return fmt.Errorf("Email field must be a non-empty string")
	}
	if len(patientInput.Gender) == 0 {
		return fmt.Errorf("Gender field must be a non-empty string")
	}
	if len(patientInput.DOB) == 0 {
		return fmt.Errorf("DOB field must be a non-empty string")
	}

	// Check if patient already exists
	patientAsBytes, err := ctx.GetStub().GetPrivateData("PayerMSPCollection", patientInput.ID)
	if err != nil {
		return fmt.Errorf("failed to get patient: %v", err)
	} else if patientAsBytes != nil {
		fmt.Println("Patient already exists: " + patientInput.ID)
		return fmt.Errorf("this patient already exists: " + patientInput.ID)
	}
	

	// Make submitting client the owner
	patientPrivateDetails := PatientPrivateDetails{
		DocType:		  patientInput.DocType,
		ID:    	 		  patientInput.ID,
		Name:  	 		  patientInput.Name,
		Phone:   		  patientInput.Phone,
		Email:	 		  patientInput.Email,
		Gender:			  patientInput.Gender,
		DOB:			  patientInput.DOB,
		PrimaryProvider:  patientInput.PrimaryProvider,
		ProviderAccess:	  []string{clientMSPID},
		CreatedBy:		  clientMSPID,
		CreatedAt:		  formattedTime,
		UpdatedBy:		  clientMSPID,
		UpdatedAt:		  formattedTime,
	}

	patientJSONasBytes, err := json.Marshal(patientPrivateDetails)
	if err != nil {
		return fmt.Errorf("failed to marshal patient into JSON: %v", err)
	}

	// Save patient to private data collection
	// Typical logger, logs to stdout/file in the fabric managed docker container, running this chaincode
	// Look for container name like dev-peer0.provider1.org-{chaincodename_version}-xyz
	log.Printf("CreatePatient Put: collection %v, ID %v", "PayerMSPCollection", patientInput.ID)

	err = ctx.GetStub().PutPrivateData("PayerMSPCollection", patientInput.ID, patientJSONasBytes)
	if err != nil {
		return fmt.Errorf("failed to put patient into private data collecton: %v", err)
	}

	
	ID := CreateHashMultiple([]byte(patientInput.ID), []byte("123"))
	hashID := base64.URLEncoding.EncodeToString(ID)

	/*primaryProvider := CreateHashMultiple([]byte(patientInput.PrimaryProvider), []byte("123"))
	hashPrimaryProvider := base64.URLEncoding.EncodeToString(primaryProvider)*/

	var hashProviderAccess []string
	//str := strings.Join(patientInput.ProviderAccess, " ")
	providerAccess := CreateHashMultiple([]byte(clientMSPID), []byte("123"))
	hashProviderAccess = []string{base64.URLEncoding.EncodeToString(providerAccess)}
	
	
	// Save patient ACL details to public state ledger visible to all organization
	patientACLDetails := &PatientACL{
		DocType:		  		patientInput.DocType,
		ID:    			  		patientInput.ID,
		HashID:			  		hashID,
		PrimaryProvider:  		patientInput.PrimaryProvider,
		ProviderAccess:	  		[]string{clientMSPID},
		HashProviderAccess:		hashProviderAccess,
		UpdatedAt:				formattedTime,
	}

	patientACLDetailsAsBytes, err := json.Marshal(patientACLDetails) // marshal patient ACL details to JSON
	if err != nil {
		return fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	// Put patient ACL into public state ledger
	log.Printf("Put ACL: ID %v", hashID)
	err = ctx.GetStub().PutState(hashID, patientACLDetailsAsBytes)
	if err != nil {
		return fmt.Errorf("failed to put patient ACL: %v", err)
	}

	return nil
}

// Approve New Patient and create a patient asset from the request asset
func (payer *Payer) ApproveNewPatient(ctx contractapi.TransactionContextInterface, patientID string, patientName string) error {
	
	dt := time.Now()
	formattedTime := dt.Format("01-02-2006 15:04:05")

	clientMSPID, err:= ctx.GetClientIdentity().GetMSPID()
	//var requestPatient *RequestPatient
	requestPatient, err := readRequestPatient(ctx, patientID, patientName)
	if requestPatient.Approved == "Yes" {
		return fmt.Errorf("The patient with the patientID %v is already approved", patientID)
	}
	var newPatient PatientPrivateDetails

	primary_Provider := requestPatient.PatientPrivateData.CreatedBy
	//newPatient = requestPatient.PatientPrivateData
	newPatient.DocType = requestPatient.PatientPrivateData.DocType
	newPatient.ID = requestPatient.PatientPrivateData.ID
	newPatient.Name = requestPatient.PatientPrivateData.Name
	newPatient.Phone = requestPatient.PatientPrivateData.Phone
	newPatient.Email = requestPatient.PatientPrivateData.Email
	newPatient.Gender = requestPatient.PatientPrivateData.Gender
	newPatient.DOB = requestPatient.PatientPrivateData.DOB
	newPatient.PrimaryProvider = primary_Provider
	newPatient.ProviderAccess = requestPatient.PatientPrivateData.ProviderAccess
	newPatient.PrimaryProvider = primary_Provider
	newPatient.CreatedBy = clientMSPID
	newPatient.CreatedAt = formattedTime
	newPatient.UpdatedBy = clientMSPID
	newPatient.UpdatedAt = formattedTime

	marshaledPatient, err := json.Marshal(&newPatient)
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %v", err)
	}
	

	err = ctx.GetStub().PutPrivateData("PayerMSPCollection", patientID, marshaledPatient)
	if err != nil {
		return fmt.Errorf("failed to put Patient data in Payer Collection: %v", err)
	}

	log.Println(primary_Provider)

	

	patientVitals := PatientVitals {
		BloodSugar:			0.0, 	  		
		Triglycerides:		0.0, 	  	
		HeartRate:			0,			
		//VitalsUpdatedBy:	clientMSPID,		
		//VitalsUpdatedAt:	formattedTime,
		//LabRequestID:		"",	
		Prescription:		[]string{""},
			
	}

	patientData := PatientData {
		PatientPrivateDetails:	newPatient,	
		PatientVitals:			patientVitals,			
	}
	
	marshaledPatientData, err := json.Marshal(patientData)
	var PayerProviderCollection = "Payer"+primary_Provider+"Collection"
	log.Println(PayerProviderCollection)
	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, patientID, marshaledPatientData)
	if err != nil {
		return fmt.Errorf("failed to put Patient data in PayerProvider Collection: %v", err)
	}

	ID := CreateHashMultiple([]byte(patientID), []byte("123"))
	hashID := base64.URLEncoding.EncodeToString(ID)

	var hashProviderAccess []string
	//str := strings.Join(patientInput.ProviderAccess, " ")
	providerAccess := CreateHashMultiple([]byte(clientMSPID), []byte("123"))
	hashProviderAccess = []string{base64.URLEncoding.EncodeToString(providerAccess)}
	providerAccess = CreateHashMultiple([]byte(newPatient.PrimaryProvider), []byte("123"))
	hashProviderAccess = append(hashProviderAccess, base64.URLEncoding.EncodeToString(providerAccess))
	
	
	
	// Save new patient ACL details to public state ledger visible to all organization
	newPatientACLDetails := &PatientACL{
		DocType:		  		newPatient.DocType,
		ID:    			  		newPatient.ID,
		HashID:			  		hashID,
		PrimaryProvider:  		newPatient.PrimaryProvider,	
		ProviderAccess:	  		[]string {clientMSPID, newPatient.PrimaryProvider},
		HashProviderAccess:		hashProviderAccess,
		UpdatedAt:				formattedTime,
	}

	newPatientACLDetailsAsBytes, err := json.Marshal(newPatientACLDetails) // marshal patient ACL details to JSON
	if err != nil {
		return fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	// Put patient ACL into public state ledger
	log.Printf("Put ACL: ID %v", hashID)
	err = ctx.GetStub().PutState(hashID, newPatientACLDetailsAsBytes)
	if err != nil {
		return fmt.Errorf("failed to put patient ACL: %v", err)
	}

	requestCompositeKey, _ := ctx.GetStub().CreateCompositeKey("request-patient.hlf-network.com", []string{patientID, patientName})

	requestPatient.Approved = "Yes"
	marshaledRequest, err := json.Marshal(requestPatient)
	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, requestCompositeKey, marshaledRequest)
	if err != nil {
		return fmt.Errorf("failed to put request data: %v", err)
	}


	return nil

}


func (payer *Payer) SetPrivateEndorsementPolicy(ctx contractapi.TransactionContextInterface, patientID string) error {

	clientMSPID, err:= ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("failed getting the client's MSPID: %v", err)
	}
	
	patientACL, err := readPatientACL(ctx, patientID)
	var PayerProviderCollection = "Payer"+patientACL.PrimaryProvider+"Collection"

    orgs := []string{"PayerMSP",patientACL.PrimaryProvider}
	epBytes, err := setEP(ctx, orgs...)
	if err != nil {
		return err
	}

	// set the endorsement policy for the key
	err = ctx.GetStub().SetPrivateDataValidationParameter(PayerProviderCollection, patientID, epBytes)
	if err != nil {
		return err
	}

	
	patientData, err := readPatient(ctx, patientID)

	if err != nil {
		return fmt.Errorf("failed to read patient record: %v", err)
	}
 
	patientData.PatientPrivateDetails.ProviderAccess = orgs

	patientPrivateDetailsAsBytes, _ := json.Marshal(patientData.PatientPrivateDetails)
	if err != nil {
		return fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	patientProviderAccessAsBytes, _ := json.Marshal(patientData)
	if err != nil {
		return fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	err = ctx.GetStub().PutPrivateData("PayerMSPCollection", patientID, patientPrivateDetailsAsBytes)
	if err != nil {
		return fmt.Errorf("failed to put ProviderAccess to patient PDC: %v", err)
	}

	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, patientID, patientProviderAccessAsBytes)
	if err != nil {
		return fmt.Errorf("failed to put ProviderAccess to patient PDC: %v", err)
	}

	err = ctx.GetStub().SetStateValidationParameter(patientID, epBytes)
	log.Printf("StateEPORGS: %v", string(epBytes))
	if err != nil {
		return err
	}

	if err != nil {
		return fmt.Errorf("failed to read patient ACL: %v", err)
	}

	ID := CreateHashMultiple([]byte(patientID), []byte("123"))
	hashID := base64.URLEncoding.EncodeToString(ID)

	var hashProviderAccess []string
	//str := strings.Join(patientInput.ProviderAccess, " ")
	providerAccess := CreateHashMultiple([]byte(clientMSPID), []byte("123"))
	hashProviderAccess = []string{base64.URLEncoding.EncodeToString(providerAccess)}
	providerAccess = CreateHashMultiple([]byte(patientACL.PrimaryProvider), []byte("123"))
	hashProviderAccess = append(hashProviderAccess, base64.URLEncoding.EncodeToString(providerAccess))

	patientACL.ProviderAccess = orgs
	patientACL.HashProviderAccess = hashProviderAccess
	

	patientACLDetailsAsBytes, err := json.Marshal(patientACL) // marshal patient ACL details to JSON
	if err != nil {
		return fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	// Put patient ACL into public state ledger
	log.Printf("Put ACL: ID %v", hashID)
	err = ctx.GetStub().PutState(hashID, patientACLDetailsAsBytes)
	if err != nil {
		return fmt.Errorf("failed to put patient ACL: %v", err)
	}

	return nil
}

// Approval by Patient to assign Primary Provider
func (payer *Payer) ApproveByPatient(ctx contractapi.TransactionContextInterface, patientID string, patientName string) error {
	
	dt := time.Now()
	formattedTime := dt.Format("01-02-2006 15:04:05")

	clientMSPID, err:= ctx.GetClientIdentity().GetMSPID()
	var requestPatient *RequestPatient
	requestPatient, err = readRequestPatient(ctx, patientID, patientName)
	if requestPatient.Approved == "Yes" {
		return fmt.Errorf("The patient with the patientID %v is already approved", patientID)
	}
	
	newPatient, err := readPayerPatientInfo(ctx, requestPatient.PatientPrivateData.ID)

	if err != nil {
		return fmt.Errorf("failed to read patient from Payer collection: %v", err)
	}

	newPatient.PrimaryProvider = requestPatient.PatientPrivateData.CreatedBy
	newPatient.UpdatedBy = clientMSPID
	//newPatient.UpdatedAt = time.Now()

	marshaledPatient, err := json.Marshal(newPatient)

	err = ctx.GetStub().PutPrivateData("PayerMSPCollection", patientID, marshaledPatient)
	if err != nil {
		return fmt.Errorf("failed to put Patient data in Payer Collection: %v", err)
	}

	patientVitals := PatientVitals {
		BloodSugar:			0.0, 	  		
		Triglycerides:		0.0, 	  	
		HeartRate:			0,			
		//VitalsUpdatedBy:	clientMSPID,		
		//VitalsUpdatedAt:	formattedTime,
		//LabRequestID:		"",		
		Prescription:		[]string{""},
	}

	patientData := &PatientData {
		PatientPrivateDetails:	*newPatient,	
		PatientVitals:			patientVitals,			
	}

	marshaledPatientData, err := json.Marshal(patientData)
	var PayerProviderCollection = "Payer"+newPatient.PrimaryProvider+"Collection"
	log.Println(PayerProviderCollection)
	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, patientID, marshaledPatientData)
	if err != nil {
		return fmt.Errorf("failed to put Patient data in PayerProvider Collection: %v", err)
	}

	ID := CreateHashMultiple([]byte(patientID), []byte("123"))
	hashID := base64.URLEncoding.EncodeToString(ID)

	var hashProviderAccess []string
	//str := strings.Join(patientInput.ProviderAccess, " ")
	providerAccess := CreateHashMultiple([]byte(clientMSPID), []byte("123"))
	hashProviderAccess = []string{base64.URLEncoding.EncodeToString(providerAccess)}
	providerAccess = CreateHashMultiple([]byte(newPatient.PrimaryProvider), []byte("123"))
	hashProviderAccess = append(hashProviderAccess, base64.URLEncoding.EncodeToString(providerAccess))
	
	
	
	// Save new patient ACL details to public state ledger visible to all organization
	newPatientACLDetails := &PatientACL{
		DocType:		  		newPatient.DocType,
		ID:    			  		newPatient.ID,
		HashID:			  		hashID,
		PrimaryProvider:  		newPatient.PrimaryProvider,	
		ProviderAccess:	  		[]string {clientMSPID, newPatient.PrimaryProvider},
		HashProviderAccess:		hashProviderAccess,
		UpdatedAt:				formattedTime,
	}

	newPatientACLDetailsAsBytes, err := json.Marshal(newPatientACLDetails) // marshal patient ACL details to JSON
	if err != nil {
		return fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	// Put patient ACL into public state ledger
	log.Printf("Put ACL: ID %v", hashID)
	err = ctx.GetStub().PutState(hashID, newPatientACLDetailsAsBytes)
	if err != nil {
		return fmt.Errorf("failed to put patient ACL: %v", err)
	}

	requestCompositeKey, _ := ctx.GetStub().CreateCompositeKey("request-patient.hlf-network.com", []string{patientID, patientName})

	requestPatient.Approved = "Yes"
	marshaledRequest, err := json.Marshal(requestPatient)
	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, requestCompositeKey, marshaledRequest)
	if err != nil {
		return fmt.Errorf("failed to put request data: %v", err)
	}


	return nil


}

func (payer *Payer) GrantPatientAccess(ctx contractapi.TransactionContextInterface, patientID string, org string)  error {

	patientData, err := readPatient(ctx, patientID)

	if err != nil {
		return fmt.Errorf("failed to read patient record: %v", err)
	}

	patientData.PatientPrivateDetails.ProviderAccess = append(patientData.PatientPrivateDetails.ProviderAccess, org)

	patientProviderAccessAsBytes, _ := json.Marshal(patientData)
	if err != nil {
		return fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	patientACL, err := readPatientACL(ctx, patientID)

	if err != nil {
		return fmt.Errorf("failed to read patient ACL: %v", err)
	}

	PayerProviderCollection := "Payer"+patientACL.PrimaryProvider+"Collection"

	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, patientID, patientProviderAccessAsBytes)
	if err != nil {
		return fmt.Errorf("failed to put ProviderAccess to patient ACL: %v", err)
	}

	ID := CreateHashMultiple([]byte(patientID), []byte("123"))
	hashID := base64.URLEncoding.EncodeToString(ID)

	var hashProviderAccess []string
	//str := strings.Join(patientInput.ProviderAccess, " ")
	providerAccess := CreateHashMultiple([]byte(org), []byte("123"))
	hashProviderAccess = append(patientACL.HashProviderAccess, base64.URLEncoding.EncodeToString(providerAccess))
	
	patientACL.ProviderAccess = append(patientACL.ProviderAccess, org)
	patientACL.HashProviderAccess = hashProviderAccess

	patientACLAsBytes, _ := json.Marshal(patientACL)
	if err != nil {
		return fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	err = ctx.GetStub().PutState(hashID, patientACLAsBytes)
	if err != nil {
		return fmt.Errorf("failed to put ProviderAccess to patient ACL: %v", err)
	}	
	
	return nil
}

func (payer *Payer) RevokePatientAccess(ctx contractapi.TransactionContextInterface, patientID string, org string)  error {
	
	patientData, err := readPatient(ctx, patientID)

	if err != nil {
		return fmt.Errorf("failed to read patient record: %v", err)
	}

	patientData.PatientPrivateDetails.ProviderAccess = deleteProvider(patientData.PatientPrivateDetails.ProviderAccess, org)

	patientProviderAccessAsBytes, _ := json.Marshal(patientData)
	if err != nil {
		return fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	patientACL, err := readPatientACL(ctx, patientID)

	if err != nil {
		return fmt.Errorf("failed to read patient ACL: %v", err)
	}

	PayerProviderCollection := "Payer"+patientACL.PrimaryProvider+"Collection"

	err = ctx.GetStub().PutPrivateData(PayerProviderCollection, patientID, patientProviderAccessAsBytes)
	if err != nil {
		return fmt.Errorf("failed to put ProviderAccess to patient ACL: %v", err)
	}

	ID := CreateHashMultiple([]byte(patientID), []byte("123"))
	hashID := base64.URLEncoding.EncodeToString(ID)

	providerAccess := CreateHashMultiple([]byte(org), []byte("123"))
	hashProviderAccess := base64.URLEncoding.EncodeToString(providerAccess)

	patientACL.ProviderAccess = deleteProvider(patientACL.ProviderAccess, org)
	patientACL.HashProviderAccess = deleteProvider(patientACL.HashProviderAccess, hashProviderAccess)

	patientACLAsBytes, _ := json.Marshal(patientACL)
	if err != nil {
		return fmt.Errorf("failed to marshal into JSON: %v", err)
	}

	err = ctx.GetStub().PutState(hashID, patientACLAsBytes)
	if err != nil {
		return fmt.Errorf("failed to put ProviderAccess to patient ACL: %v", err)
	}
	
	return nil
}



func setEP(ctx contractapi.TransactionContextInterface,  orgs ...string) ([]byte, error) {
	ep, err := statebased.NewStateEP(nil)
	if err != nil {
		return nil, err
	}
	// add organizations to endorsement policy
	err = ep.AddOrgs(statebased.RoleTypePeer, orgs...)
	if err != nil {
		return nil, err
	}

	log.Printf("List of EP Orgs: %v",ep.ListOrgs())

	epBytes, err := ep.Policy()
	if err != nil {
		return nil, err
	}
	
	return epBytes, nil
}

	// verifyClientOrgMatchesPeerOrg is an internal function used verify client org id and matches peer org id.
	func verifyClientOrgMatchesPeerOrg(ctx contractapi.TransactionContextInterface) error {
		clientMSPID, err := ctx.GetClientIdentity().GetMSPID()
		if err != nil {
			return fmt.Errorf("failed getting the client's MSPID: %v", err)
		}
		peerMSPID, err := shim.GetMSPID()
		if err != nil {
			return fmt.Errorf("failed getting the peer's MSPID: %v", err)
		}
	
		if clientMSPID == "PayerMSP" {
			return fmt.Errorf("client from org %v is not authorized to create patient", clientMSPID)
		}
	
		if clientMSPID != peerMSPID {
			if peerMSPID != "PayerMSP"{
				return fmt.Errorf("client from org %v is not authorized to create patient", clientMSPID)
			}
		}
	
		return nil
	}
	
	func submittingClientIdentity(ctx contractapi.TransactionContextInterface) (string, error) {
		b64ID, err := ctx.GetClientIdentity().GetID()
		if err != nil {
			return "", fmt.Errorf("Failed to read clientID: %v", err)
		}
		decodeID, err := base64.StdEncoding.DecodeString(b64ID)
		if err != nil {
			return "", fmt.Errorf("failed to base64 decode clientID: %v", err)
		}
		return string(decodeID), nil
	}


/*func (payer *PayerSmartContract) ReadKeyEndorsementPolicy(ctx contractapi.TransactionContextInterface, patientID string) (string, error) {
	
	clientMSPID, err:= ctx.GetClientIdentity().GetMSPID()

	if err != nil {
		return "", fmt.Errorf("failed getting the client's MSPID: %v", err)
	}
	
	//var "PayerMSPCollection" = "Payer"+clientMSPID+"Collection"
	
	epPrivate, err := ctx.GetStub().GetPrivateDataValidationParameter("PayerMSPCollection", patientID)

	fmt.Println(string(epPrivate))
	log.Printf("Key Endorsement Policy is: %v", string(epPrivate))

	//epState, err := ctx.GetStub().GetStateValidationParameter(patientID)

	//log.Printf("Key Endorsement Policy is: %v", string(epState))

	return string(epPrivate), nil

}*/

// ReadPatient reads the information from collection
func readPatient(ctx contractapi.TransactionContextInterface, patientID string) (*PatientData, error) {
	//var payerContract *payer.Payer
	//var provider *provider.Provider
	var patient *PatientData
	
	clientMSPID, _:= ctx.GetClientIdentity().GetMSPID()

	/*if clientMSPID == "PayerMSP" {
		patient, err = payer.readPatient(ctx, patientID)
	}

	if clientMSPID == "Provider1MSP" || clientMSPID == "Provider2MSP" {

	}*/

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
func readPatientACL(ctx contractapi.TransactionContextInterface, patientID string) (*PatientACL, error) {


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

	var patientACL PatientACL
	err = json.Unmarshal(patientACLJSON, &patientACL)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	return &patientACL, nil

}

// ReadPayerPatientInfo reads the patient personal details from collection
func readPayerPatientInfo(ctx contractapi.TransactionContextInterface, patientID string) (*PatientPrivateDetails, error) {

	clientMSPID, _:= ctx.GetClientIdentity().GetMSPID()

	if clientMSPID != "PayerMSP" {
		return nil, fmt.Errorf("client from org %v is not authorized to read patient details", clientMSPID)
	}

	patientJSON, err := ctx.GetStub().GetPrivateData("PayerMSPCollection", patientID) //get the patient details from chaincode state
	if err != nil {
		return nil, fmt.Errorf("failed to read patient: %v", err)
	}

	//No Patient found, return empty response
	if patientJSON == nil {
		log.Printf("%v does not exist in collection %v", patientID, "PayerMSPCollection")
		return nil, nil
	}

	var patient *PatientPrivateDetails
	err = json.Unmarshal(patientJSON, &patient)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	return patient, nil
}

// ReadRequestPatient reads the information from collection
func readRequestPatient(ctx contractapi.TransactionContextInterface, patientID string, patientName string) (*RequestPatient, error) {
	var PayerProviderCollection string
	
	clientMSPID, _:= ctx.GetClientIdentity().GetMSPID()

	clientID := CreateHashMultiple([]byte(clientMSPID), []byte("123"))
	hashClientMSPID := base64.URLEncoding.EncodeToString(clientID)

	requestCompositeKey, _ := ctx.GetStub().CreateCompositeKey("request-patient.hlf-network.com", []string{patientID, patientName})

	requestPatientACL, err := readRequestPatientACL(ctx, patientID, patientName)

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

	var requestPatient RequestPatient
	err = json.Unmarshal(requestPatientJSON, &requestPatient)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	return &requestPatient, nil

}

// ReadRequestPatientACL reads the request patient information from state ledger
func  readRequestPatientACL(ctx contractapi.TransactionContextInterface, patientID string, patientName string) (*RequestPatientACL, error) {

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

	var requestPatientACL RequestPatientACL
	err = json.Unmarshal(requestPatientACLJSON, &requestPatientACL)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	return &requestPatientACL, nil

}

func deleteProvider(providerAccess []string, org string) []string {
    index := 0
    for _, i := range providerAccess {
        if i != org {
            providerAccess[index] = i
            index++
        }
    }
    return providerAccess[:index]
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
