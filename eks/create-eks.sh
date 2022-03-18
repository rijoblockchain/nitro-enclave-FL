#!/usr/bin/env bash

# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# This script is similar to ./create-eks.sh. The difference - it does not create the bastion host

region=us-east-1
privateNodegroup=true # set to true if you want eksctl to create the EKS worker nodes in private subnets


# echo Download the kubectl and heptio-authenticator-aws binaries and save to ~/bin
# mkdir ~/bin
# wget https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && mv kubectl ~/bin/
# curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator && chmod +x aws-iam-authenticator && mv aws-iam-authenticator ~/bin/

echo Download eksctl from eksctl.io
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/v0.67.0/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

echo Create a keypair
cd ~
aws ec2 create-key-pair --key-name eks-healthcare-keypair --region $region --query 'KeyMaterial' --output text > eks-healthcare-keypair.pem
chmod 400 eks-healthcare-keypair.pem
sleep 10

echo Create the EKS cluster
if [ $privateNodegroup == "true" ]; then
    privateOption="--node-private-networking"
else
    privateOption=""
fi

cd ~
if [ $region == "us-east-1" ]; then
    eksctl create cluster ${privateOption} --ssh-access --ssh-public-key eks-healthcare-keypair --name eks-healthcare --nodes=1 --region $region --kubeconfig=./kubeconfig.eks-healthcare.yaml --zones=us-east-1a,us-east-1b,us-east-1d
else
    eksctl create cluster ${privateOption} --ssh-access --ssh-public-key eks-healthcare-keypair --name eks-healthcare --nodes=1 --region $region --kubeconfig=./kubeconfig.eks-healthcare.yaml
fi

echo Check whether kubectl can access your Kubernetes cluster
kubectl --kubeconfig=./kubeconfig.eks-healthcare.yaml get nodes

echo installing jq
#sudo apt -y install jq
#sudo yum -y install jq    #for rpm based 

echo Getting VPC and Subnets from eksctl
VPCID=$(eksctl get cluster --name=eks-healthcare --region $region --verbose=0 --output=json | jq  '.[0].ResourcesVpcConfig.VpcId' | tr -d '"')
echo -e "VPCID: $VPCID"

SUBNETS=$(eksctl get cluster --name=eks-healthcare --region $region --verbose=0 --output=json | jq  '.[0].ResourcesVpcConfig.SubnetIds')
NUMSUBNETS=${#SUBNETS[@]}
echo -e "Checking that 6 subnets have been created. eksctl created ${NUMSUBNETS} subnets"

if [ $NUMSUBNETS neq 6 ]; then
    echo -e "6 subnets have not been created for this EKS cluster. There should be 3 public and 3 private. This script will fail if it continues. Stopping now. Investigate why eksctl did not create the required number of subnets"
    exit 1
fi

SUBNETA=$(echo $SUBNETS | jq '.[0]' | tr -d '"')
SUBNETB=$(echo $SUBNETS | jq '.[1]' | tr -d '"')
SUBNETC=$(echo $SUBNETS | jq '.[2]' | tr -d '"')
echo -e "SUBNETS: $SUBNETS"
echo -e "SUBNETS: $SUBNETA, $SUBNETB, $SUBNETC"

KEYPAIRNAME="eks-healthcare-keypair"
echo $KEYPAIRNAME

cd ~/healthcare-blockchain-3.0-k8
#git checkout efs/deploy-ec2.sh
echo ${VPCID}
echo Update the ~/healthcare-blockchain-3.0-k8/efs/deploy-ec2.sh config file
sed -e "s/{VPCID}/${VPCID}/g" -e "s/{REGION}/${region}/g" -e "s/{SUBNETA}/${SUBNETA}/g" -e "s/{SUBNETB}/${SUBNETB}/g" -e "s/{SUBNETC}/${SUBNETC}/g"  -e "s/{KEYPAIRNAME}/${KEYPAIRNAME}/g" -i ~/healthcare-blockchain-3.0-k8/efs/deploy-ec2.sh

echo ~/healthcare-blockchain-3.0-k8/efs/deploy-ec2.sh script has been updated with your parameters
#cat ~/healthcare-blockchain-3.0-k8/efs/deploy-ec2.sh

echo Running ~/healthcare-blockchain-3.0-k8/efs/deploy-ec2.sh - this will use CloudFormation to create the EFS
cd ~/healthcare-blockchain-3.0-k8/
./efs/deploy-ec2.sh

PublicDnsNameBastion=$(aws ec2 describe-instances --region $region --filters "Name=tag:Name,Values=EFS FileSystem Mounted Instance" "Name=instance-state-name,Values=running" | jq '.Reservations | .[] | .Instances | .[] | .PublicDnsName' | tr -d '"')
echo public DNS of EC2 bastion host: $PublicDnsNameBastion

if [ "$privateNodegroup" == "true" ]; then
    PrivateDnsNameEKSWorker=$(aws ec2 describe-instances --region $region --filters "Name=tag:Name,Values=eks-healthcare-*-Node" "Name=instance-state-name,Values=running" | jq '.Reservations | .[] | .Instances | .[] | .PrivateDnsName' | tr -d '"')
    echo private DNS of EKS worker nodes, accessible from Bastion only since they are in a private subnet: $PrivateDnsNameEKSWorker
    cd ~
    # we need the keypair on the bastion, since we can only access the K8s worker nodes from the bastion
    scp -i eks-healthcare-keypair.pem -q ~/eks-healthcare-keypair.pem  ec2-user@${PublicDnsNameBastion}:/home/ec2-user/eks-healthcare-keypair.pem #-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
else
    PublicDnsNameEKSWorker=$(aws ec2 describe-instances --region $region --filters "Name=tag:Name,Values=eks-healthcare-*-Node" "Name=instance-state-name,Values=running" | jq '.Reservations | .[] | .Instances | .[] | .PublicDnsName' | tr -d '"')
    echo public DNS of EKS worker nodes: $PublicDnsNameEKSWorker
fi

echo Prepare the EC2 bastion for use by copying the kubeconfig and aws config and credentials files
cd ~
scp -i eks-healthcare-keypair.pem -q ~/kubeconfig.eks-healthcare.yaml  ec2-user@${PublicDnsNameBastion}:/home/ec2-user/kubeconfig.eks-healthcare.yaml
scp -i eks-healthcare-keypair.pem -q ~/.aws/config  ec2-user@${PublicDnsNameBastion}:/home/ec2-user/config
scp -i eks-healthcare-keypair.pem -q ~/.aws/credentials  ec2-user@${PublicDnsNameBastion}:/home/ec2-user/credentials
