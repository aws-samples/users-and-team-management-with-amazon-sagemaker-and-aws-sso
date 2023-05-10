#!/usr/bin/env bash
. ~/.bash_profile

export VPCCIDR="10.0.0.0/16"
export SAMLBackendPrivateSubnetCIDR="10.0.0.0/19"
export SageMakerDomainPrivateSubnetCIDR="10.0.32.0/19"
export PublicSubnetCIDR="10.0.128.0/20"

echo "Creating VPC"
VPC_TAGS=ResourceType=vpc,Tags=[{Key=Name,Value=vpc-${ENV_NAME}},{Key=EnvironmentName,Value=${ENV_NAME}}]
export VPC_ID=$(aws ec2 create-vpc \
                --cidr-block ${VPCCIDR} \
                --tag-specification ${VPC_TAGS} \
                --query "Vpc.VpcId" \
                --output text
               )
aws ec2 modify-vpc-attribute \
    --vpc-id ${VPC_ID} \
    --enable-dns-hostnames "{\"Value\":true}"

aws ec2 modify-vpc-attribute \
    --vpc-id ${VPC_ID} \
    --enable-dns-support "{\"Value\":true}"
    
echo "export VPC_ID=${VPC_ID}" | tee -a ~/.bash_profile

echo "Creating SAML Backend Private Subnet"
SAML_SUBNET_TAGS=ResourceType=subnet,Tags=[{Key=Name,Value=private-sn-1a--${ENV_NAME}-saml-backend},{Key=EnvironmentName,Value=${ENV_NAME}}]
export SAMLBackendPrivateSubnetID=$(aws ec2 create-subnet \
                --vpc-id ${VPC_ID} \
                --availability-zone ${AWS_REGION}a \
                --cidr-block ${SAMLBackendPrivateSubnetCIDR} \
                --tag-specifications ${SAML_SUBNET_TAGS} \
                --query "Subnet.SubnetId" \
                --output text
                )
echo "export SAMLBackendPrivateSubnetID=${SAMLBackendPrivateSubnetID}" | tee -a ~/.bash_profile

echo "Creating SageMaker Domain Private Subnet"
SM_DOMAIN_SUBNET_TAGS=ResourceType=subnet,Tags=[{Key=Name,Value=private-sn-1a-${ENV_NAME}-sm-domain},{Key=EnvironmentName,Value=${ENV_NAME}}]
export SageMakerDomainPrivateSubnetID=$(aws ec2 create-subnet \
                --vpc-id ${VPC_ID} \
                --availability-zone ${AWS_REGION}a \
                --cidr-block ${SageMakerDomainPrivateSubnetCIDR} \
                --tag-specifications ${SM_DOMAIN_SUBNET_TAGS} \
                --query "Subnet.SubnetId" \
                --output text
                )
echo "export SageMakerDomainPrivateSubnetID=${SageMakerDomainPrivateSubnetID}" | tee -a ~/.bash_profile

echo "Public Subnet"
PUBLIC_SUBNET_TAGS=ResourceType=subnet,Tags=[{Key=Name,Value=public-sn-1a-${ENV_NAME}},{Key=EnvironmentName,Value=${ENV_NAME}}]
export PublicSubnetID=$(aws ec2 create-subnet \
                --vpc-id ${VPC_ID} \
                --availability-zone ${AWS_REGION}a \
                --cidr-block ${PublicSubnetCIDR} \
                --tag-specifications ${PUBLIC_SUBNET_TAGS} \
                --query "Subnet.SubnetId" \
                --output text
                )
aws ec2 modify-subnet-attribute \
 --subnet-id ${PublicSubnetID} \
 --map-public-ip-on-launch
 
echo "export PublicSubnetID=${PublicSubnetID}" | tee -a ~/.bash_profile

# Creating Security Groups, Egress and Ingress Rules
echo "Creating SageMaker Domain Security Group"
SM_DOMAIN_SG_TAGS=ResourceType=security-group,Tags=[{Key=Name,Value=sg-${ENV_NAME}-sm-domain},{Key=EnvironmentName,Value=${ENV_NAME}}]
export SageMakerDomainSecurityGroupID=$(aws ec2 create-security-group \
                --group-name SageMakerDomainSecurityGroup \
                --description "SageMaker domain security group" \
                --vpc-id ${VPC_ID} \
                --tag-specifications ${SM_DOMAIN_SG_TAGS} \
                --query "GroupId" \
                --output text
                )
echo "Adding Ingress Rule to SageMaker Domain Security Group"
INGRESS_DESC="Allow inbound traffic from ${VPCCIDR}"
aws ec2 authorize-security-group-ingress \
 --group-id ${SageMakerDomainSecurityGroupID} \
 --ip-permissions IpProtocol=-1,FromPort=0,ToPort=65535,IpRanges="[{CidrIp=${VPCCIDR},Description=${INGRESS_DESC}}]" 2>&1 > /dev/null

echo "export SageMakerDomainSecurityGroupID=${SageMakerDomainSecurityGroupID}" | tee -a ~/.bash_profile

echo "Creating SAML Backend Security Group"
SAML_BACKEND_SG_TAGS=ResourceType=security-group,Tags=[{Key=Name,Value=sg-${ENV_NAME}-saml-backend},{Key=EnvironmentName,Value=${ENV_NAME}}]
export SAMLBackendSecurityGroupID=$(aws ec2 create-security-group \
                --group-name SAMLBackendSecurityGroup \
                --description "SAML backend security group" \
                --vpc-id ${VPC_ID} \
                --tag-specifications ${SAML_BACKEND_SG_TAGS} \
                --query "GroupId" \
                --output text
                )
echo "Adding Ingress Rule to SAML Backend Security Group"
INGRESS_DESC="Allow inbound traffic from ${VPCCIDR}"
aws ec2 authorize-security-group-ingress \
 --group-id ${SAMLBackendSecurityGroupID} \
 --ip-permissions IpProtocol=-1,FromPort=0,ToPort=65535,IpRanges="[{CidrIp=${VPCCIDR},Description=${INGRESS_DESC}}]" 2>&1 > /dev/null

INGRESS_DESC="Allow ingress TCP 443 from SageMaker domain security group"
aws ec2 authorize-security-group-ingress \
 --group-id ${SAMLBackendSecurityGroupID} \
 --protocol tcp \
 --port 443 \
 --source-group ${SageMakerDomainSecurityGroupID}

echo "export SAMLBackendSecurityGroupID=${SAMLBackendSecurityGroupID}" | tee -a ~/.bash_profile

echo "Creating VPCE Security Group"
VPCE_SG_TAGS=ResourceType=security-group,Tags=[{Key=Name,Value=sg-${ENV_NAME}-vpce},{Key=EnvironmentName,Value=${ENV_NAME}}]
export VPCESecurityGroupID=$(aws ec2 create-security-group \
                --group-name VPCESecurityGroup \
                --description "VPC endpoints security group" \
                --vpc-id ${VPC_ID} \
                --tag-specifications ${VPCE_SG_TAGS} \
                --query "GroupId" \
                --output text
                )
echo "Adding Ingress Rule to VPCE Security Group"
INGRESS_DESC="Allow inbound traffic from ${VPCCIDR}"
aws ec2 authorize-security-group-ingress \
 --group-id ${VPCESecurityGroupID} \
 --ip-permissions IpProtocol=-1,FromPort=0,ToPort=65535,IpRanges="[{CidrIp=${VPCCIDR},Description=${INGRESS_DESC}}]" 2>&1 > /dev/null

INGRESS_DESC="Allow ingress TCP 443 from SageMaker domain security group"
aws ec2 authorize-security-group-ingress \
 --group-id ${VPCESecurityGroupID} \
 --protocol tcp \
 --port 443 \
 --source-group ${SageMakerDomainSecurityGroupID}

echo "export VPCESecurityGroupID=${VPCESecurityGroupID}" | tee -a ~/.bash_profile

# Creating Internet Gateway
echo "Creating Internet Gateway"
IGW_TAGS=ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-${ENV_NAME}},{Key=EnvironmentName,Value=${ENV_NAME}}]
export InternetGatewayID=$(aws ec2 create-internet-gateway \
                --tag-specifications ${IGW_TAGS} \
                --query "InternetGateway.InternetGatewayId" \
                --output text)
echo "Attaching Internet Gateway to VPC"
aws ec2 attach-internet-gateway \
    --internet-gateway-id ${InternetGatewayID} \
    --vpc-id ${VPC_ID}

echo "export InternetGatewayID=${InternetGatewayID}" | tee -a ~/.bash_profile

# Creating NAT Gateway
echo "Creating NAT Gateway Public IP Allocation"
EIP_TAGS=ResourceType=elastic-ip,Tags=[{Key=Name,Value=eip-${ENV_NAME}},{Key=EnvironmentName,Value=${ENV_NAME}}]
export NatGatewayEIP=$(aws ec2 allocate-address \
            --tag-specifications ${EIP_TAGS} \
            --query 'AllocationId'\
            --output text)

NATGW_TAGS=ResourceType=natgateway,Tags=[{Key=Name,Value=nat-gw-1-${ENV_NAME}},{Key=EnvironmentName,Value=${ENV_NAME}}]
export NATGW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id ${PublicSubnetID} \
    --allocation-id ${NatGatewayEIP} \
    --tag-specifications ${NATGW_TAGS} \
    --query "NatGateway.NatGatewayId" \
    --output text)

echo "export NatGatewayEIP=${NatGatewayEIP}" | tee -a ~/.bash_profile
echo "export NATGW_ID=${NATGW_ID}" | tee -a ~/.bash_profile

# Creating and configuring Route Tables
echo "Creating Route Table for Public Subnet"
PUB_ROUTE_TABLE_TAGS=ResourceType=route-table,Tags=[{Key=Name,Value=public-rtb-${ENV_NAME}},{Key=EnvironmentName,Value=${ENV_NAME}}]

export PublicRouteTableID=$(aws ec2 create-route-table \
                  --tag-specifications ${PUB_ROUTE_TABLE_TAGS} \
                  --query "RouteTable.RouteTableId" \
                  --output text \
                  --vpc-id ${VPC_ID})
echo "Creatin default route to Internet Gateway"
aws ec2 create-route --route-table-id ${PublicRouteTableID} \
  --destination-cidr-block 0.0.0.0/0 --gateway-id ${InternetGatewayID} 2>&1 > /dev/null

echo "Creating route table association for Public Subnet"
aws ec2 associate-route-table \
  --route-table-id ${PublicRouteTableID} --subnet-id ${PublicSubnetID} 2>&1 > /dev/null

echo "export PublicRouteTableID=${PublicRouteTableID}" | tee -a ~/.bash_profile

echo "Creating Route Table Private Subnets"
PRIV_ROUTE_TABLE_TAGS=ResourceType=route-table,Tags=[{Key=Name,Value=private-rtb-1a-${ENV_NAME}},{Key=EnvironmentName,Value=${ENV_NAME}}]

export PrivateRouteTableID=$(aws ec2 create-route-table \
                  --tag-specifications ${PRIV_ROUTE_TABLE_TAGS} \
                  --query "RouteTable.RouteTableId" \
                  --output text \
                  --vpc-id ${VPC_ID})
echo "Creatin default route to NAT Gateway"
aws ec2 create-route --route-table-id ${PrivateRouteTableID} \
  --destination-cidr-block 0.0.0.0/0 --gateway-id ${NATGW_ID} 2>&1 > /dev/null

echo "Creating route table association for SAML Backend Private Subnet"
aws ec2 associate-route-table \
  --route-table-id ${PrivateRouteTableID} --subnet-id ${SAMLBackendPrivateSubnetID} 2>&1 > /dev/null

echo "Creating route table association for SageMaker Domain Private Subnet"
aws ec2 associate-route-table \
  --route-table-id ${PrivateRouteTableID} --subnet-id ${SageMakerDomainPrivateSubnetID} 2>&1 > /dev/null

echo "export PrivateRouteTableID=${PrivateRouteTableID}" | tee -a ~/.bash_profile

echo "Creating VPC Endpoints for API Gateway in the SAML Backend Private Subnet"
aws ec2 create-vpc-endpoint \
  --vpc-id ${VPC_ID} \
  --vpc-endpoint-type Interface \
  --private-dns-enabled \
  --service-name com.amazonaws.${AWS_REGION}.execute-api \
  --security-group-ids ${VPCESecurityGroupID} \
  --subnet-ids ${SAMLBackendPrivateSubnetID} 2>&1 > /dev/null

echo "Creating VPC Endpoints for SageMaker Studio in the SageMaker Domain Private Subnet"
aws ec2 create-vpc-endpoint \
  --vpc-id ${VPC_ID} \
  --vpc-endpoint-type Interface \
  --private-dns-enabled \
  --service-name aws.sagemaker.${AWS_REGION}.studio \
  --security-group-ids ${VPCESecurityGroupID} \
  --subnet-ids ${SageMakerDomainPrivateSubnetID} 2>&1 > /dev/null
  
echo "Creating VPC Endpoints for SageMaker API in the SageMaker Domain Private Subnet"
aws ec2 create-vpc-endpoint \
  --vpc-id ${VPC_ID} \
  --vpc-endpoint-type Interface \
  --private-dns-enabled \
  --service-name com.amazonaws.${AWS_REGION}.sagemaker.api \
  --security-group-ids ${VPCESecurityGroupID} \
  --subnet-ids ${SageMakerDomainPrivateSubnetID} 2>&1 > /dev/null

echo "Creating VPC Endpoints for SageMaker Runtime in the SageMaker Domain Private Subnet"
aws ec2 create-vpc-endpoint \
  --vpc-id ${VPC_ID} \
  --vpc-endpoint-type Interface \
  --private-dns-enabled \
  --service-name com.amazonaws.${AWS_REGION}.sagemaker.runtime \
  --security-group-ids ${VPCESecurityGroupID} \
  --subnet-ids ${SageMakerDomainPrivateSubnetID} 2>&1 > /dev/null

