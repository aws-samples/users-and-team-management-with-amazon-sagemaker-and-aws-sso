#!/usr/bin/bash
source ~/.bash_profile

# Deleting SAML Backend Lambda Function
echo "Disconnecting SAML Backend Lambda Function from the VPC"
aws lambda update-function-configuration \
    --function-name SAMLBackEndFunction-${RANDOM_STRING} \
    --vpc-config SubnetIds=[],SecurityGroupIds=[] 2>&1 > /dev/null

sleep 120

echo "Deleting SAML Backend Lambda Function"
aws lambda delete-function \
    --function-name SAMLBackEndFunction-${RANDOM_STRING}

sleep 60

# aws-support-tools/Lambda/FindEniMappings
# findEniAssociations --eni eni-0123456789abcef01 --region us-east-1

# Deleting API Gateway
echo "Deleting API Gateway"
aws apigateway delete-rest-api \
    --rest-api-id ${SageMakerDomainSAMLAPIID}

# Deleting SageMaker Domain ID from SSM Parameter Store
echo "Deleting SageMaker Domain ID from SSM Parameter Store"
aws ssm delete-parameter \
    --name ${ENV_NAME}-sagemaker-domain-id

# Disabling access to Service Catalog portfolio for SageMaker
echo "Disabling access to Service Catalog portfolio for SageMaker"
export PortfolioID=$(aws servicecatalog list-accepted-portfolio-shares \
    --query 'PortfolioDetails[?ProviderName==`Amazon SageMaker`].Id' \
    --output text
)

aws servicecatalog disassociate-principal-from-portfolio \
    --portfolio-id ${PortfolioID} \
    --principal-arn arn:aws:iam::${ACCOUNT_ID}:role/SageMakerStudioExecutionRoleDefault-${RANDOM_STRING}
aws servicecatalog list-principals-for-portfolio \
    --portfolio-id ${PortfolioID} \
    --query 'Principals[?PrincipalARN==`arn:aws:iam::'${ACCOUNT_ID}':role/SageMakerStudioExecutionRoleDefault-'${RANDOM_STRING}'`]' \
    --output text

# Disabling Service Catalog Portfolio
echo "Disabling Service Catalog Portfolio"
export ServiceCatalogPortfolioStatusCurrent=$(aws sagemaker get-sagemaker-servicecatalog-portfolio-status \
--query "Status" \
--output text
)

if [ "${ServiceCatalogPortfolioStatus}" == "Disabled" -a ${ServiceCatalogPortfolioStatusCurrent} == "Enabled" ]
then
    aws sagemaker disable-sagemaker-servicecatalog-portfolio
fi

export UserProfileList=$(aws sagemaker list-user-profiles \
    --domain-id-equals ${SageMakerDomainID} \
    --query 'UserProfiles[*].UserProfileName' \
    --output text | \
    xargs
)

# Deleting SageMaker Domain application associations
# and user profiles
echo "Deleting SageMaker Domain application associations and user profiles"
for UP in $UserProfileList
do
    aws sagemaker delete-app \
        --domain-id ${SageMakerDomainID} \
        --user-profile-name ${UP} \
        --app-type JupyterServer \
        --app-name default

    sleep 30
    
    aws sagemaker delete-user-profile \
        --domain-id ${SageMakerDomainID} \
        --user-profile-name ${UP}
done

sleep 60

# Deleting SageMaker Domain
echo "Deleting SageMaker Domain"
aws sagemaker delete-domain \
    --domain-id ${SageMakerDomainID} \
    --retention-policy HomeEfsFileSystem=Delete

sleep 120

# Deleting SageMaker Roles and Policies
echo "Detaching policies from SAML Backend Lambda Execution Role"
aws iam detach-role-policy \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerPermissionsPolicy-${RANDOM_STRING}

aws iam detach-role-policy \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam detach-role-policy \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy

aws iam delete-role-policy \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING} \
    --policy-name AccessVPCResources

aws iam delete-role-policy \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING} \
    --policy-name PassExecutionRole

echo "Deleting SAML Backend Lambda Execution Role"
aws iam delete-role \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING}

echo "Detaching policies from SageMaker Studio Execution Role for Team 2"
aws iam detach-role-policy \
    --role-name SageMakerStudioExecutionRoleTeam2-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerReadOnlyPolicy-${RANDOM_STRING}

aws iam detach-role-policy \
    --role-name SageMakerStudioExecutionRoleTeam2-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerDeniedServicesPolicy-${RANDOM_STRING}

aws iam detach-role-policy \
    --role-name SageMakerStudioExecutionRoleTeam2-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerAccessSupportingServicesPolicy-${RANDOM_STRING}

aws iam detach-role-policy \
    --role-name SageMakerStudioExecutionRoleTeam2-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerStudioDeveloperAccessPolicy-${RANDOM_STRING}

echo "Deleting SageMaker Studio Execution Role for Team 2"
aws iam delete-role \
    --role-name SageMakerStudioExecutionRoleTeam2-${RANDOM_STRING}

echo "Detaching policies from SageMaker Studio Execution Role for Team 1"
aws iam detach-role-policy \
    --role-name SageMakerStudioExecutionRoleTeam1-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerReadOnlyPolicy-${RANDOM_STRING}

aws iam detach-role-policy \
    --role-name SageMakerStudioExecutionRoleTeam1-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerDeniedServicesPolicy-${RANDOM_STRING}

aws iam detach-role-policy \
    --role-name SageMakerStudioExecutionRoleTeam1-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerAccessSupportingServicesPolicy-${RANDOM_STRING}

aws iam detach-role-policy \
    --role-name SageMakerStudioExecutionRoleTeam1-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerStudioDeveloperAccessPolicy-${RANDOM_STRING}

echo "Deleting SageMaker Studio Execution Role for Team 1"
aws iam delete-role \
    --role-name SageMakerStudioExecutionRoleTeam1-${RANDOM_STRING}

echo "Detaching policies from Studio Execution Role"
aws iam detach-role-policy \
    --role-name SageMakerStudioExecutionRoleDefault-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerReadOnlyPolicy-${RANDOM_STRING}

aws iam detach-role-policy \
    --role-name SageMakerStudioExecutionRoleDefault-${RANDOM_STRING} \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerDeniedServicesPolicy-${RANDOM_STRING}

echo "Deleting SageMaker Studio Execution Role"
aws iam delete-role \
    --role-name SageMakerStudioExecutionRoleDefault-${RANDOM_STRING}

# Deleting IAM Policies
echo "Deleting SageMaker Denied Services Policy"
aws iam delete-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerStudioDeveloperAccessPolicy-${RANDOM_STRING}

echo "Deleting SageMaker Access Supporting Services Policy"
aws iam delete-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerAccessSupportingServicesPolicy-${RANDOM_STRING}

echo "Deleting SageMaker SageMaker Read Only Policy"
aws iam delete-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerReadOnlyPolicy-${RANDOM_STRING}

echo "Deleting SageMaker Studio Developer Access Policy"
aws iam delete-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerDeniedServicesPolicy-${RANDOM_STRING}

echo "Deleting Restrict SageMaker To CIDR Policy"
aws iam delete-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/RestrictSageMakerToCIDRPolicy-${RANDOM_STRING}

echo "Deleting SageMaker Permissions Policy"
aws iam delete-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerPermissionsPolicy-${RANDOM_STRING}

# Delete VPC Endpoints
echo "Deleting API Gateway VPC Endpoint"
APIGW_ENDPOINT_ID=$(
    aws ec2 describe-vpc-endpoints \
        --query 'VpcEndpoints[?(ServiceName==`com.amazonaws.'${AWS_REGION}'.execute-api` && VpcId==`'${VPC_ID}'`)].VpcEndpointId' \
        --output text
    )

aws ec2 delete-vpc-endpoints \
    --vpc-endpoint-ids ${APIGW_ENDPOINT_ID} 2>&1 > /dev/null

echo "Deleting SageMaker Studio VPC Endpoint"
SMSTUDIO_ENDPOINT_ID=$(
    aws ec2 describe-vpc-endpoints \
        --query 'VpcEndpoints[?(ServiceName==`aws.sagemaker.'${AWS_REGION}'.studio` && VpcId==`'${VPC_ID}'`)].VpcEndpointId' \
        --output text
    )

aws ec2 delete-vpc-endpoints \
    --vpc-endpoint-ids ${SMSTUDIO_ENDPOINT_ID} 2>&1 > /dev/null

echo "Deleting SageMaker API VPC Endpoint"
SMAPI_ENDPOINT_ID=$(
    aws ec2 describe-vpc-endpoints \
        --query 'VpcEndpoints[?(ServiceName==`com.amazonaws.'${AWS_REGION}'.sagemaker.api` && VpcId==`'${VPC_ID}'`)].VpcEndpointId' \
        --output text
    )

aws ec2 delete-vpc-endpoints \
    --vpc-endpoint-ids ${SMAPI_ENDPOINT_ID} 2>&1 > /dev/null

echo "Deleting SageMaker Runtime VPC Endpoint"
SMRT_ENDPOINT_ID=$(
    aws ec2 describe-vpc-endpoints \
        --query 'VpcEndpoints[?(ServiceName==`com.amazonaws.'${AWS_REGION}'.sagemaker.runtime` && VpcId==`'${VPC_ID}'`)].VpcEndpointId' \
        --output text
    )

aws ec2 delete-vpc-endpoints \
    --vpc-endpoint-ids ${SMRT_ENDPOINT_ID} 2>&1 > /dev/null

# Deleting Routes and Route Tables for Private Subnet
echo "Removing route table association for SageMaker Domain Subnet"
export SageMakerDomainRouteTableAssoc=$(aws ec2 describe-route-tables \
                       --route-table-ids ${PrivateRouteTableID} \
                       --query 'RouteTables[*].Associations[?SubnetId==`'${SageMakerDomainPrivateSubnetID}'`].RouteTableAssociationId' \
                       --output text
                       )
echo "Removing route table association for SAML Backend Subnet"
export SAMLBackendRouteTableAssoc=$(aws ec2 describe-route-tables \
                       --route-table-ids ${PrivateRouteTableID} \
                       --query 'RouteTables[*].Associations[?SubnetId==`'${SAMLBackendPrivateSubnetID}'`].RouteTableAssociationId' \
                       --output text
                       )
aws ec2 disassociate-route-table \
    --association-id ${SageMakerDomainRouteTableAssoc}
aws ec2 disassociate-route-table \
    --association-id ${SAMLBackendRouteTableAssoc}

echo "Deleting Private Subnet Route Table"
aws ec2 delete-route-table \
    --route-table-id ${PrivateRouteTableID}

# Deleting Routes and Route Tables for Public Subnet
echo "Removing route table association"
export PublicRouteTableAssoc=$(aws ec2 describe-route-tables \
                       --route-table-ids ${PublicRouteTableID} \
                       --query 'RouteTables[*].Associations[?SubnetId==`'${PublicSubnetID}'`].RouteTableAssociationId' \
                       --output text
                       )
aws ec2 disassociate-route-table \
    --association-id ${PublicRouteTableAssoc}

echo "Deleting Route Table Public Subnet"
aws ec2 delete-route-table \
    --route-table-id ${PublicRouteTableID} 2>&1 > /dev/null

# Delete NAT Gateway
echo "Deleting NAT Gateway"
aws ec2 delete-nat-gateway \
    --nat-gateway-id ${NATGW_ID} 2>&1 > /dev/null

sleep 120

echo "Releasing EIP"
aws ec2 release-address \
    --allocation-id ${NatGatewayEIP} 2>&1 > /dev/null

# Delete Internet Gateway
echo "Detaching Internet Gateway from VPC"
aws ec2 detach-internet-gateway \
    --internet-gateway-id ${InternetGatewayID} \
    --vpc-id ${VPC_ID}

echo "Deleting Internet Gateway"
aws ec2 delete-internet-gateway \
    --internet-gateway-id ${InternetGatewayID} 2>&1 > /dev/null

# Delete Security Groups
sleep 120
echo "Deleting VPCE Security Group"
aws ec2 delete-security-group --group-id ${VPCESecurityGroupID}

echo "Deleting SAML Backend Security Group"
aws ec2 delete-security-group --group-id ${SAMLBackendSecurityGroupID}

echo "Deleting SageMaker Domain Security Group"
aws ec2 delete-security-group --group-id ${SageMakerDomainSecurityGroupID}

# Delete Subnets
echo "Deleting Public Subnet"
aws ec2 delete-subnet --subnet-id ${PublicSubnetID}

echo "Deleting SageMaker Domain Private Subnet"
aws ec2 delete-subnet --subnet-id ${SageMakerDomainPrivateSubnetID}

echo "Deleting SAML Backend Private Subnet"
aws ec2 delete-subnet --subnet-id ${SAMLBackendPrivateSubnetID}

# Delete VPC
aws ec2 delete-vpc --vpc-id ${VPC_ID}

#
echo "Removing Environemnt Variables from .bash_profile"
sed -i '/export ENV_NAME/d' ~/.bash_profile
sed -i '/export ACCOUNT_ID/d' ~/.bash_profile
sed -i '/export AWS_REGION/d' ~/.bash_profile
sed -i '/export AWS_DEFAULT_REGION/d' ~/.bash_profile
sed -i '/export RANDOM_STRING/d' ~/.bash_profile
sed -i '/export VPC_ID/d' ~/.bash_profile
sed -i '/export SAMLBackendPrivateSubnetID/d' ~/.bash_profile
sed -i '/export SageMakerDomainPrivateSubnetID/d' ~/.bash_profile
sed -i '/export PublicSubnetID/d' ~/.bash_profile
sed -i '/export SageMakerDomainSecurityGroupID/d' ~/.bash_profile
sed -i '/export SAMLBackendSecurityGroupID/d' ~/.bash_profile
sed -i '/export VPCESecurityGroupID/d' ~/.bash_profile
sed -i '/export InternetGatewayID/d' ~/.bash_profile
sed -i '/export NatGatewayEIP/d' ~/.bash_profile
sed -i '/export NATGW_ID/d' ~/.bash_profile
sed -i '/export PublicRouteTableID/d' ~/.bash_profile
sed -i '/export PrivateRouteTableID/d' ~/.bash_profile
sed -i '/export SageMakerDomainID/d' ~/.bash_profile
sed -i '/export ServiceCatalogPortfolioStatus/d' ~/.bash_profile
sed -i '/export SageMakerDomainSAMLAPIID/d' ~/.bash_profile

unset ENV_NAME
unset ACCOUNT_ID
unset AWS_REGION
unset AWS_DEFAULT_REGION
unset RANDOM_STRING
unset VPC_ID
unset SAMLBackendPrivateSubnetID
unset SageMakerDomainPrivateSubnetID
unset PublicSubnetID
unset SageMakerDomainSecurityGroupID
unset SAMLBackendSecurityGroupID
unset VPCESecurityGroupID
unset InternetGatewayID
unset NatGatewayEIP
unset NATGW_ID
unset PublicRouteTableID
unset PrivateRouteTableID
unset SageMakerDomainID
unset ServiceCatalogPortfolioStatus
unset SageMakerDomainSAMLAPIID

rm -rf $HOME/.ssh/id_rsa