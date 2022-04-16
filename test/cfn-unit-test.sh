# Test CFN template isolated

# set variables
export ENV_NAME="sagemaker-team-mgmt-sso"

# VPC
aws cloudformation deploy \
    --template-file cfn-templates/vpc.yaml \
    --stack-name $ENV_NAME-vpc \
    --parameter-overrides \
    EnvironmentName=$ENV_NAME