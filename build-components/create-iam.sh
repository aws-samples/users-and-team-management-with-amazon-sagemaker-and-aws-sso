#!/usr/bin/env bash
. ~/.bash_profile

# Creating Custom SageMaker IAM Policies
echo "Creating SageMaker Denied Services Policy"
envsubst < build-components/iam-policy-templates/SageMakerDeniedServicesPolicy.json | \
xargs -0 -I {} aws iam create-policy \
    --description "Explicit deny for specific SageMaker services" \
    --tags Key=EnvironmentName,Value=${ENV_NAME} \
    --policy-name SageMakerDeniedServicesPolicy-${RANDOM_STRING} \
    --policy-document {} 2>&1 > /dev/null

echo "Creating SageMaker Read Only Policy"
envsubst < build-components/iam-policy-templates/SageMakerReadOnlyPolicy.json | \
xargs -0 -I {} aws iam create-policy \
    --description "Read-only baseline policy for SageMaker execution role" \
    --tags Key=EnvironmentName,Value=${ENV_NAME} \
    --policy-name SageMakerReadOnlyPolicy-${RANDOM_STRING} \
    --policy-document {} 2>&1 > /dev/null

echo "Creating SageMaker Access Supporting Services Policy"
envsubst < build-components/iam-policy-templates/SageMakerAccessSupportingServicesPolicy.json | \
xargs -0 -I {} aws iam create-policy \
    --description "Read-only baseline policy for SageMaker execution role" \
    --tags Key=EnvironmentName,Value=${ENV_NAME} \
    --policy-name SageMakerAccessSupportingServicesPolicy-${RANDOM_STRING} \
    --policy-document {} 2>&1 > /dev/null

echo "Creating SageMaker Studio Developer Access Policy"
envsubst < build-components/iam-policy-templates/SageMakerStudioDeveloperAccessPolicy.json | \
xargs -0 -I {} aws iam create-policy \
    --description "Read-only baseline policy for SageMaker execution role" \
    --tags Key=EnvironmentName,Value=${ENV_NAME} \
    --policy-name SageMakerStudioDeveloperAccessPolicy-${RANDOM_STRING} \
    --policy-document {} 2>&1 > /dev/null

echo "Creating Restrict SageMaker To CIDR Policy"
envsubst < build-components/iam-policy-templates/RestrictSageMakerToCIDRPolicy.json | \
xargs -0 -I {} aws iam create-policy \
    --description "Policy to restrict SageMaker to specific CIDR" \
    --tags Key=EnvironmentName,Value=${ENV_NAME} \
    --policy-name RestrictSageMakerToCIDRPolicy-${RANDOM_STRING} \
    --policy-document {} 2>&1 > /dev/null

echo "Creating SageMaker Permissions Policy"
envsubst < build-components/iam-policy-templates/SageMakerPermissionsPolicy.json | \
xargs -0 -I {} aws iam create-policy \
    --description "Policy to allow creation of user profiles" \
    --tags Key=EnvironmentName,Value=${ENV_NAME} \
    --policy-name SageMakerPermissionsPolicy-${RANDOM_STRING} \
    --policy-document {} 2>&1 > /dev/null

# Creating SageMaker Studio IAM Roles
echo "Creating SageMaker Studio Execution Role"
envsubst < build-components/iam-policy-templates/sagemaker-trust-policy.json | \
xargs -0 -I {} aws iam create-role \
    --role-name SageMakerStudioExecutionRoleDefault-${RANDOM_STRING} \
    --tags Key=EnvironmentName,Value=${ENV_NAME} \
    --assume-role-policy-document {} 2>&1 > /dev/null
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerDeniedServicesPolicy-${RANDOM_STRING} \
    --role-name SageMakerStudioExecutionRoleDefault-${RANDOM_STRING}
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerReadOnlyPolicy-${RANDOM_STRING} \
    --role-name SageMakerStudioExecutionRoleDefault-${RANDOM_STRING}

echo "Creating SageMaker Studio Execution Role for Team 1"
envsubst < build-components/iam-policy-templates/sagemaker-trust-policy.json | \
xargs -0 -I {} aws iam create-role \
    --role-name SageMakerStudioExecutionRoleTeam1-${RANDOM_STRING} \
    --tags Key=EnvironmentName,Value=${ENV_NAME} \
           Key=Team,Value=Team1 \
    --assume-role-policy-document {} 2>&1 > /dev/null
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerReadOnlyPolicy-${RANDOM_STRING} \
    --role-name SageMakerStudioExecutionRoleTeam1-${RANDOM_STRING}
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerAccessSupportingServicesPolicy-${RANDOM_STRING} \
    --role-name SageMakerStudioExecutionRoleTeam1-${RANDOM_STRING}
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerStudioDeveloperAccessPolicy-${RANDOM_STRING} \
    --role-name SageMakerStudioExecutionRoleTeam1-${RANDOM_STRING}
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerDeniedServicesPolicy-${RANDOM_STRING} \
    --role-name SageMakerStudioExecutionRoleTeam1-${RANDOM_STRING}

echo "Creating SageMaker Studio Execution Role for Team 2"
envsubst < build-components/iam-policy-templates/sagemaker-trust-policy.json | \
xargs -0 -I {} aws iam create-role \
    --role-name SageMakerStudioExecutionRoleTeam2-${RANDOM_STRING} \
    --tags Key=EnvironmentName,Value=${ENV_NAME} \
           Key=Team,Value=Team2 \
    --assume-role-policy-document {} 2>&1 > /dev/null
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerReadOnlyPolicy-${RANDOM_STRING} \
    --role-name SageMakerStudioExecutionRoleTeam2-${RANDOM_STRING}
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerAccessSupportingServicesPolicy-${RANDOM_STRING} \
    --role-name SageMakerStudioExecutionRoleTeam2-${RANDOM_STRING}
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerStudioDeveloperAccessPolicy-${RANDOM_STRING} \
    --role-name SageMakerStudioExecutionRoleTeam2-${RANDOM_STRING}
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerDeniedServicesPolicy-${RANDOM_STRING} \
    --role-name SageMakerStudioExecutionRoleTeam2-${RANDOM_STRING}

echo "Creating SAML Backend Lambda Execution Role"
envsubst < build-components/iam-policy-templates/lambda-trust-policy.json | \
xargs -0 -I {} aws iam create-role \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING} \
    --tags Key=EnvironmentName,Value=${ENV_NAME} \
    --assume-role-policy-document {} 2>&1 > /dev/null
envsubst < build-components/iam-policy-templates/AccessVPCResources-inline-policy.json | \
xargs -0 -I {} aws iam put-role-policy \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING} \
    --policy-name AccessVPCResources \
    --policy-document {}
envsubst < build-components/iam-policy-templates/PassExecutionRole-inline-policy.json | \
xargs -0 -I {} aws iam put-role-policy \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING} \
    --policy-name PassExecutionRole \
    --policy-document {}
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/SageMakerPermissionsPolicy-${RANDOM_STRING} \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING}
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING}
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy \
    --role-name SAMLBackendLambdaExecutionRole-${RANDOM_STRING}
