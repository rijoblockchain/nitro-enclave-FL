region=us-east-1
privateNodegroup=true # set to true if you want eksctl to create the EKS worker nodes in private subnets

PublicDnsNameBastion=$(aws ec2 describe-instances --region $region --filters "Name=tag:Name,Values=EFS FileSystem Mounted Instance" "Name=instance-state-name,Values=running" | jq '.Reservations | .[] | .Instances | .[] | .PublicDnsName' | tr -d '"')
echo public DNS of EC2 bastion host: $PublicDnsNameBastion

if [ "$privateNodegroup" == "true" ]; then
    PrivateDnsNameEKSWorker=$(aws ec2 describe-instances --region $region --filters "Name=tag:Name,Values=eks-healthcare-*-Node" "Name=instance-state-name,Values=running" | jq '.Reservations | .[] | .Instances | .[] | .PrivateDnsName' | tr -d '"')
    echo private DNS of EKS worker nodes, accessible from Bastion only since they are in a private subnet: $PrivateDnsNameEKSWorker
    cd ~
    # we need the keypair on the bastion, since we can only access the K8s worker nodes from the bastion
    scp -i eks-healthcare-keypair.pem -q ~/eks-healthcare-keypair.pem  ec2-user@${PublicDnsNameBastion}:/home/ec2-user/eks-healthcare-keypair.pem
else
    PublicDnsNameEKSWorker=$(aws ec2 describe-instances --region $region --filters "Name=tag:Name,Values=eks-healthcare-*-Node" "Name=instance-state-name,Values=running" | jq '.Reservations | .[] | .Instances | .[] | .PublicDnsName' | tr -d '"')
    echo public DNS of EKS worker nodes: $PublicDnsNameEKSWorker
fi

echo Prepare the EC2 bastion for use by copying the kubeconfig and aws config and credentials files
cd ~
scp -i eks-healthcare-keypair.pem -q ~/kubeconfig.eks-healthcare.yaml  ec2-user@${PublicDnsNameBastion}:/home/ec2-user/kubeconfig.eks-healthcare.yaml
scp -i eks-healthcare-keypair.pem -q ~/.aws/config  ec2-user@${PublicDnsNameBastion}:/home/ec2-user/config
scp -i eks-healthcare-keypair.pem -q ~/.aws/credentials  ec2-user@${PublicDnsNameBastion}:/home/ec2-user/credentials




<<'COMMENT'
region={REGION}
vpcid={VPCID}
subneta={SUBNETA}
subnetb={SUBNETB}
subnetc={SUBNETC}
keypairname={KEYPAIRNAME}
volumename=dltefs
mountpoint=opt/share2
COMMENT