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
    SAMLBackendPrivateSubnetCIDR=$SAMLBACKEND_SN_CIDR \
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

# Get the domain id
export DOMAIN_ID=$(aws sagemaker list-domains --output text --query 'Domains[0].DomainId')

# Get the execution roles
export STACK_NAME=<SAM stack name>
export EXEC_ROLE_TEAM1=$(aws cloudformation describe-stacks --stack-name $STACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="SageMakerStudioExecutionRoleTeam1Arn") | .OutputValue')
export EXEC_ROLE_TEAM2=$(aws cloudformation describe-stacks --stack-name $STACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="SageMakerStudioExecutionRoleTeam2Arn") | .OutputValue')

# Get SSO user id
export SSO_STORE_ID=<Identity Store ID>
export SSO_USER1_NAME=<User 1 Name>
export SSO_USER2_NAME=<User 1 Name>g

export SSO_USER1_ID=$(aws identitystore list-users --identity-store-id $SSO_STORE_ID --filter AttributePath='UserName',AttributeValue=$SSO_USER1_NAME --query 'Users[0].UserId' --output text)
export SSO_USER2_ID=$(aws identitystore list-users --identity-store-id $SSO_STORE_ID --filter AttributePath='UserName',AttributeValue=$SSO_USER2_NAME --query 'Users[0].UserId' --output text)

# Create Studio user profiles
aws sagemaker create-user-profile \
  --domain-id $DOMAIN_ID \
  --user-profile-name $SSO_USER1_ID-Team1 \
  --tags Key=studiouserid,Value=ilyiny+demo@amazon.com \
  --user-settings ExecutionRole=$EXEC_ROLE_TEAM1

aws sagemaker create-user-profile \
  --domain-id $DOMAIN_ID \
  --user-profile-name $SSO_USER1_ID-Team2 \
  --tags Key=studiouserid,Value=ilyiny+demo@amazon.com \
  --user-settings ExecutionRole=$EXEC_ROLE_TEAM2

aws sagemaker create-user-profile \
  --domain-id $DOMAIN_ID \
  --user-profile-name $SSO_USER2_ID-Team2 \
  --tags Key=studiouserid,Value=ilyiny+demo-sm-sso-2@amazon.com \
  --user-settings ExecutionRole=$EXEC_ROLE_TEAM2

# List the tags assigned to a user profile
export USER_PROFILE_ARN=$(aws sagemaker describe-user-profile \
  --user-profile-name <user-profile-name> \
  --domain-id $DOMAIN_ID \
  --output text --query 'UserProfileArn')

aws sagemaker list-tags --resource-arn $USER_PROFILE_ARN
