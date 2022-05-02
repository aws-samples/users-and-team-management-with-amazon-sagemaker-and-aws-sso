# Test CFN template isolated

# set variables
export ENV_NAME="sagemaker-team-mgmt-sso"

########## VPC ##########
# use cases:
# 1. New VPC - the stack creates all network infrastructure
# 2. Existing VPC, new private subnets - the stack creates private subnets, security groups, and VPC endpoints
# 3. Existing VPC, existing private subnets - the stack creates security groups and VPC endpoints

aws cloudformation validate-template \
    --template-body file://cfn-templates/vpc.yaml

# 1. New VPC
aws cloudformation deploy \
    --template-file cfn-templates/vpc.yaml \
    --stack-name $ENV_NAME-vpc \
    --parameter-overrides \
    EnvironmentName=$ENV_NAME

# 2. Existing VPC, new private subnets
export VPC_ID=vpc-c513e9b8
export VPCCIDR=$(aws ec2 describe-vpcs --filters Name="vpc-id",Values=$VPC_ID \
    --output text \
    --query 'Vpcs[0].CidrBlock')

# CIDR blocks for private subnets
export SAMLBACKEND_SN_CIDR="172.31.96.0/19"
export SMDOMAIN_SN_CIDR="172.31.128.0/19"

aws cloudformation deploy \
    --template-file cfn-templates/vpc.yaml \
    --stack-name $ENV_NAME-vpc \
    --parameter-overrides \
    EnvironmentName=$ENV_NAME \
    ExistingVPCId=$VPC_ID \
    VPCCIDR=$VPCCIDR \
    SAMLBackedPrivateSubnetCIDR=$SAMLBACKEND_SN_CIDR \
    SageMakerDomainPrivateSubnetCIDR=$SMDOMAIN_SN_CIDR

# 3. Existing VPC, existing private subnets
export SAMLBACKEND_SN_ID=subnet-0ded16799f1a327d6
export SMDOMAIN_SN_ID=subnet-0cbd39976e7509a90

aws cloudformation deploy \
    --template-file cfn-templates/vpc.yaml \
    --stack-name $ENV_NAME-vpc \
    --parameter-overrides \
    EnvironmentName=$ENV_NAME \
    ExistingVPCId=$VPC_ID \
    VPCCIDR=$VPCCIDR \
    CreatePrivateSubnets=NO \
    ExistingSAMLBackendPrivateSubnetId=$SAMLBACKEND_SN_ID \
    ExistingSageMakerDomainPrivateSubnetId=$SMDOMAIN_SN_ID

########## IAM ##########
export ALLOWED_CIDR=172.31.0.0/16

aws cloudformation deploy \
    --template-file cfn-templates/iam.yaml \
    --stack-name $ENV_NAME-iam \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
    EnvironmentName=$ENV_NAME \
    AllowedCIDR=$ALLOWED_CIDR

########## SageMaker Domain ##########

##########
export VPC_ID=<VPC ID>
export VPCCIDR=$(aws ec2 describe-vpcs --filters Name="vpc-id",Values=$VPC_ID \
    --output text \
    --query 'Vpcs[0].CidrBlock')


export DOMAIN_ID=$(aws sagemaker list-domains --output text --query 'Domains[0].DomainId')
export SUBNET_IDS=$(aws sagemaker describe-domain --domain-id $DOMAIN_ID --output text --query 'SubnetIds[*]')

aws ec2 describe-subnets \
    --subnet-ids ${SUBNET_IDS} \
    --filters Name="availability-zone",Values=${AWS_DEFAULT_REGION}a \
    --output text \
    --query 'Subnets[].CidrBlock'

# SageMaker domain authentication mode
aws sagemaker describe-domain --domain-id $DOMAIN_ID --output text --query 'AuthMode'
