#!/usr/bin/env bash



# copy the file env.sh from the Fabric orderer network to S3
function copyEnvToS3 {
    echo "Copying the env file to S3"
    if [[ $(aws configure list) && $? -eq 0 ]]; then
        echo $S3BucketNameOrderer
        aws s3api put-object --bucket $S3BucketNameOrderer --key ${ORDERER_ORG}/env.sh --body ${SCRIPTS}/env.sh
        # aws s3api put-object-acl --bucket $S3BucketNameOrderer --key ${ORDERER_ORG}/env.sh --grant-read uri=http://acs.amazonaws.com/groups/global/AllUsers
        #aws s3api put-object-acl --bucket $S3BucketNameOrderer --key ${ORDERER_ORG}/env.sh --acl public-read
    else
        echo "AWS CLI is not configured on this node. To run this script install and configure the AWS CLI"
    fi
    echo "Copying the env file to S3 complete"
}

# copy the file env.sh from S3 to the new Fabric org
function copyEnvFromS3 {
    echo "Copying the env file from S3"
    if [[ $(aws configure list) && $? -eq 0 ]]; then
        #sudo chown ec2-user ${SCRIPTS}/env.sh
        aws s3api get-object --bucket $S3BucketNameNewOrg --key $NEW_ORG/env.sh ${SCRIPTS}/${NEW_ORG}env.sh
        sudo chown root:root ${SCRIPTS}/${NEW_ORG}env.sh
        sudo chmod 777 ${SCRIPTS}/${NEW_ORG}env.sh
    else
        echo "AWS CLI is not configured on this node. To run this script install and configure the AWS CLI"
    fi
    echo "Copying the env file from S3 complete"
}

# copy the certificates for the new Fabric org from S3 to the Fabric orderer network
function copyCertsFromS3 {
    echo "Copying the certs from S3"
    source ${SCRIPTS}/${NEW_ORG}env.sh
    if [[ $(aws configure list) && $? -eq 0 ]]; then
        COUNT=1
        getDomain $NEW_ORG
        aws s3api get-object --bucket $S3BucketNameNewOrg --key ${NEW_ORG}/${DOMAIN}msp.tar $DATADIR/organizations/fabric-ca/$NEW_ORG/$NEW_ORG-${DOMAIN}msp.tar
        sudo tar xvf $DATADIR/organizations/fabric-ca/$NEW_ORG/$NEW_ORG-${DOMAIN}msp.tar -C $DATADIR/organizations/fabric-ca/$NEW_ORG/
        sudo cp -R $DATADIR/organizations/fabric-ca/$NEW_ORG/opt/share/efs/organizations/fabric-ca/$NEW_ORG/msp $DATADIR/organizations/fabric-ca/$NEW_ORG/
        sudo rm -rf $DATADIR/organizations/fabric-ca/$NEW_ORG/opt
        sleep 10s
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            aws s3api get-object --bucket $S3BucketNameNewOrg --key peer$COUNT-${NEW_ORG}/peer$COUNT-${NEW_ORG}msp.tar $DATADIR/organizations/fabric-ca/$NEW_ORG/peer$COUNT-${NEW_ORG}msp.tar
            sudo tar xvf $DATADIR/organizations/fabric-ca/$NEW_ORG/peer$COUNT-${NEW_ORG}msp.tar -C $DATADIR/organizations/fabric-ca/$NEW_ORG/
            sudo cp -R $DATADIR/organizations/fabric-ca/$NEW_ORG/opt/share/efs/organizations/* $DATADIR/organizations/fabric-ca/$NEW_ORG
            sudo rm -rf $DATADIR/organizations/fabric-ca/$NEW_ORG/opt
            COUNT=$((COUNT+1))
        done
    else
        echo "AWS CLI is not configured on this node. To run this script install and configure the AWS CLI"
    fi
    echo "Copying the certs from S3 complete"
}

# copy the orderer PEM file from the Fabric orderer network to S3
function copyOrdererPEMToS3 {
    echo "Copying the orderer PEM file to S3"
    getDomain $ORDERER_ORG
    sudo cp $DATADIR/organizations/ordererOrganizations/$DOMAIN/msp/tlscacerts/tlsca.$DOMAIN-cert.pem $DATADIR/organizations/ordererOrganizations/$DOMAIN
    if [[ $(aws configure list) && $? -eq 0 ]]; then
        aws s3api put-object --bucket $S3BucketNameOrderer --key $ORDERER_ORG/tlsca.$DOMAIN-cert.pem --body $DATADIR/organizations/ordererOrganizations/$DOMAIN/tlsca.$DOMAIN-cert.pem
        #aws s3api put-object-acl --bucket $S3BucketNameOrderer --key $ORDERER_ORG/$ORDERER_ORG-ca-cert.pem --grant-read uri=http://acs.amazonaws.com/groups/global/AllUsers
        #aws s3api put-object-acl --bucket $S3BucketNameOrderer --key $ORDERER_ORG/$ORDERER_ORG-ca-cert.pem --acl public-read
    else
        echo "AWS CLI is not configured on this node. To run this script install and configure the AWS CLI"
    fi
    echo "Copying the orderer PEM file to S3 complete"
}


# copy the Channel Genesis block from the Fabric orderer network to S3
function copyChannelGenesisToS3 {
    echo "Copying the Channel Genesis block to S3"
    if [[ $(aws configure list) && $? -eq 0 ]]; then
        aws s3api put-object --bucket $S3BucketNameOrderer --key $ORDERER_ORG/$CHANNEL_NAME.block --body $DATADIR/channel-artifacts/$CHANNEL_NAME.block
        #aws s3api put-object-acl --bucket $S3BucketNameOrderer --key org0/mychannel.block --grant-read uri=http://acs.amazonaws.com/groups/global/AllUsers
        #aws s3api put-object-acl --bucket $S3BucketNameOrderer --key org0/mychannel.block --acl public-read
    else
        echo "AWS CLI is not configured on this node. To run this script install and configure the AWS CLI"
    fi
    echo "Copying the Channel Genesis block to S3 complete"
}


# create S3 bucket to copy files from the Fabric orderer organisation. Bucket will be read-only to other organisations
function createS3BucketForOrderer {
    #create the s3 bucket
    echo -e "creating s3 bucket for orderer org: $S3BucketNameOrderer"
    #quick way of determining whether the AWS CLI is installed and a default profile exists
    if [[ $(aws configure list) && $? -eq 0 ]]; then
        if [[ "$region" == "us-east-1" ]]; then
            aws s3api create-bucket --bucket $S3BucketNameOrderer --region $region
        else
            aws s3api create-bucket --bucket $S3BucketNameOrderer --region $region --create-bucket-configuration LocationConstraint=$region
        fi
        aws s3api put-bucket-acl --bucket $S3BucketNameOrderer --grant-read uri=http://acs.amazonaws.com/groups/global/AllUsers
        aws s3api put-bucket-acl --bucket $S3BucketNameOrderer --acl public-read
    else
        echo "AWS CLI is not configured on this node. To run this script install and configure the AWS CLI"
    fi
    echo "Creating the S3 bucket complete"
}


HOME=$1
REPO=$2
DATADIR=$3
NEW_ORG=$4
SCRIPTS=$DATADIR/scripts
#DATA=$DATADIR/rca-data
region=us-east-1
S3BucketNameOrderer=blockboard-blockchain-orderer-1
S3BucketNameNewOrg=blockboard-blockchain-$NEW_ORG


set -e

source $SCRIPTS/env.sh

orgsarr=($ORDERER_ORGS)
ORDERER_ORG=${orgsarr[0]}

