#!/usr/bin/env bash
. ~/.bash_profile

# Creating SageMaker Domain
export SageMakerDomainArn=$(aws sagemaker create-domain \
    --domain-name ${ENV_NAME}-${AWS_REGION}-sagemaker-domain \
    --tags Key=EnvironmentName,Value=${ENV_NAME} \
    --auth-mode IAM \
    --default-user-settings \
        "ExecutionRole=arn:aws:iam::${ACCOUNT_ID}:role/SageMakerStudioExecutionRoleDefault-${RANDOM_STRING},\
        SecurityGroups=${SageMakerDomainSecurityGroupID}" \
    --subnet-ids ${SageMakerDomainPrivateSubnetID} \
    --vpc-id ${VPC_ID} \
    --app-network-access-type VpcOnly \
    --query "DomainArn" \
    --output text
    )

export SageMakerDomainID=$(aws sagemaker list-domains \
    --query 'Domains[?DomainArn==`'${SageMakerDomainArn}'`].DomainId' \
    --output text
    )
echo "export SageMakerDomainID=${SageMakerDomainID}" | tee -a ~/.bash_profile

SageMakerDomainStatus=$(aws sagemaker list-domains \
    --query 'Domains[?DomainArn==`'${SageMakerDomainArn}'`].Status' \
    --output text
    )

while [ "${SageMakerDomainStatus}" != "InService" ]
do
    sleep 30
    SageMakerDomainStatus=$(aws sagemaker list-domains \
    --query 'Domains[?DomainArn==`'${SageMakerDomainArn}'`].Status' \
    --output text
    )
done

# Enabling Service Catalog Portfolio for SageMaker & associating Studio Domain Principal
echo "Enabling Service Catalog Portfolio for Amazon SageMaker"
export ServiceCatalogPortfolioStatus=$(aws sagemaker get-sagemaker-servicecatalog-portfolio-status \
--query "Status" \
--output text
)
echo "export ServiceCatalogPortfolioStatus=${ServiceCatalogPortfolioStatus}" | tee -a ~/.bash_profile


if [ "${ServiceCatalogPortfolioStatus}" != "Enabled" ]
then
    aws sagemaker enable-sagemaker-servicecatalog-portfolio
fi

export PortfolioID=$(aws servicecatalog list-accepted-portfolio-shares \
    --query 'PortfolioDetails[?ProviderName==`Amazon SageMaker`].Id' \
    --output text
)

if [ "X${PortfolioID}" != "X" ]
then
    echo ${PortfolioID}
else
    echo "Null"
fi

echo "Associating SageMaker Studio principal with Service Catalog portfolio for SageMaker"
aws servicecatalog associate-principal-with-portfolio \
    --portfolio-id ${PortfolioID} \
    --principal-arn arn:aws:iam::${ACCOUNT_ID}:role/SageMakerStudioExecutionRoleDefault-${RANDOM_STRING} \
    --principal-type 'IAM' 2>&1 > /dev/null

# Save Studio Domain in SSM Parameter Store
aws ssm put-parameter \
    --name ${ENV_NAME}-sagemaker-domain-id \
    --description "SageMaker Studio Domain for ${ENV_NAME}" \
    --type "String" \
    --value ${SageMakerDomainID} \
    --tags Key=EnvironmentName,Value=${ENV_NAME}

