#!/usr/bin/env bash
. ~/.bash_profile

# Creating SAML Back End Function
echo "Creating SAML Back End Function"
(cd build-components/lambda-code/SAMLBackEndFunction && zip -r ../../saml_backend_function.zip .)
aws lambda create-function \
    --function-name SAMLBackEndFunction-${RANDOM_STRING} \
    --runtime python3.8 \
    --package-type Zip \
    --zip-file fileb://build-components/saml_backend_function.zip \
    --timeout 60 \
    --handler saml_backend_function.lambda_handler \
    --role arn:aws:iam::${ACCOUNT_ID}:role/SAMLBackendLambdaExecutionRole-${RANDOM_STRING} \
    --environment "Variables=`envsubst < build-components/lambda-code/lambda-env-template.json`" \
    --vpc-config SubnetIds=${SAMLBackendPrivateSubnetID},SecurityGroupIds=${SAMLBackendSecurityGroupID} \
    --tags Key=EnvironmentName,Value=${ENV_NAME} 2>&1 > /dev/null
export SAMLBackEndFunctionARN=arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:SAMLBackEndFunction-${RANDOM_STRING}
rm -rf build-components/saml_backend_function.zip

# Creating API Gateway REST API
echo "Creating API Gateway REST API"
export SageMakerDomainSAMLAPIID=$(aws apigateway create-rest-api \
        --name SageMakerDomainSAMLAPI-${RANDOM_STRING} \
        --endpoint-configuration types=REGIONAL \
        --query "id" \
        --output text
)

# Updating API Gateway Resource Policy
echo "Updating API Gateway Resource Policy"
aws apigateway update-rest-api \
    --rest-api-id ${SageMakerDomainSAMLAPIID} \
    --patch-operations op=replace,path=/policy,value=\'"`envsubst < build-components/api-gateway/resource-policy-template.json`"\' 2>&1 > /dev/null

echo "export SageMakerDomainSAMLAPIID=${SageMakerDomainSAMLAPIID}" | tee -a ~/.bash_profile

export RootResourceID=$(aws apigateway get-resources \
    --rest-api-id ${SageMakerDomainSAMLAPIID} \
    --region ${AWS_REGION} \
    --query 'items[?path==`/`].id' \
    --output text
)

echo "Creating resource /saml"
export SAMLResourceID=$(aws apigateway create-resource \
    --region ${AWS_REGION} \
    --rest-api-id ${SageMakerDomainSAMLAPIID} \
    --parent-id ${RootResourceID} \
    --path-part 'saml' \
    --query 'id' \
    --output text
)

echo "Adding POST method to /saml"
aws apigateway put-method \
    --region ${AWS_REGION} \
    --rest-api-id ${SageMakerDomainSAMLAPIID} \
    --resource-id ${SAMLResourceID} \
    --http-method POST \
    --authorization-type "NONE" 2>&1 > /dev/null

echo "Creating proxy integration with SAML Backend Lambda"
aws apigateway put-integration \
    --region ${AWS_REGION} \
    --rest-api-id ${SageMakerDomainSAMLAPIID} \
    --resource-id ${SAMLResourceID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${SAMLBackEndFunctionARN}/invocations" 2>&1 > /dev/null

# Creating API Gateway prod tage
echo "Creating API Gateway Deployment"
export SageMakerDomainSAMLAPIDeploymentID=$(aws apigateway create-deployment \
    --region ${AWS_REGION} \
    --rest-api-id ${SageMakerDomainSAMLAPIID} \
    --stage-name Stage \
    --stage-description 'Stage' \
    --query 'id' \
    --output text
)

sleep 30

export SageMakerDomainSAMLAPIDeploymentID=$(aws apigateway create-deployment \
    --region ${AWS_REGION} \
    --rest-api-id ${SageMakerDomainSAMLAPIID} \
    --stage-name prod \
    --stage-description 'Prod Stage' \
    --query 'id' \
    --output text
)

# Allow Lambda Invocation by API Gateway
echo "Additing Lambda Invocation permissions for API Gateway"
aws lambda add-permission \
  --function-name SAMLBackEndFunction-${RANDOM_STRING} \
  --statement-id SAMLBackEndFunctionPermissionApiGateway-${RANDOM_STRING} \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${SageMakerDomainSAMLAPIID}/*/POST/saml" 2>&1 > /dev/null

export SAMLAudience="https://${SageMakerDomainSAMLAPIID}.execute-api.us-east-1.amazonaws.com/"
export AppACSURL="https://${SageMakerDomainSAMLAPIID}.execute-api.us-east-1.amazonaws.com/prod/saml"

echo "SAML Audience: ${SAMLAudience}"
echo "ACS URL: ${AppACSURL}"
