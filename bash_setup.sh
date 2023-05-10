#!/usr/bin/env bash
. ~/.bash_profile

sudo yum -y update

echo "Installing helper tools"
sudo yum -y install jq

echo "Uninstalling AWS CLI 1.x"
sudo pip uninstall awscli -y

echo "Installing AWS CLI 2.x"
curl --silent --no-progress-meter \
    "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o "awscliv2.zip"
unzip -qq awscliv2.zip
sudo ./aws/install --update
PATH=/usr/local/bin:$PATH
/usr/local/bin/aws --version
rm -rf aws awscliv2.zip

export ENV_NAME="sagemaker-team-mgmt-sso"
echo "export ENV_NAME=${ENV_NAME}" | tee -a ~/.bash_profile

export InstanceID=$(curl --silent --no-progress-meter \
                    http://169.254.169.254/latest/dynamic/instance-identity/document \
                    | jq -r '.instanceId')

export InstanceProfileID=$(aws ec2 describe-instances \
    --instance-ids ${InstanceID} \
    --query 'Reservations[*].Instances[?InstanceId==`'${InstanceID}'`].IamInstanceProfile.Id' \
    --output text
)

export InstanceRole=$(aws iam list-instance-profiles \
    --query 'InstanceProfiles[?InstanceProfileId==`'${InstanceProfileID}'`].Roles[0].RoleName' \
    --output text
)

export AttachedPolicy=$(aws iam list-attached-role-policies \
    --role-name ${InstanceRole} \
    --query 'AttachedPolicies[?PolicyName==`AdministratorAccess`].PolicyName' \
    --output text | xargs
)

if [ "${AttachedPolicy}" == "AdministratorAccess" ]
then
    export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    export AWS_REGION=$(curl --silent --no-progress-meter \
                        http://169.254.169.254/latest/dynamic/instance-identity/document \
                        | jq -r '.region')
    export AWS_DEFAULT_REGION=$AWS_REGION
    
    echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
    echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
    echo "export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}" | tee -a ~/.bash_profile
    aws configure set default.region ${AWS_REGION}
    aws configure get default.region
    
    RANDOM_STRING=$(cat /dev/urandom \
                    | tr -dc '[:alpha:]' \
                    | fold -w ${1:-20} | head -n 1 \
                    | cut -c 1-8 \
                    | tr '[:upper:]' '[:lower:]')
    echo "export RANDOM_STRING=${RANDOM_STRING}" | tee -a ~/.bash_profile
    
    sh build-components/create-vpc.sh
    sh build-components/create-iam.sh
    sh build-components/create-sagemaker.sh
    sh build-components/create-app.sh
else
    echo "Please assign an instance role with the AdministratorAccess IAM policy attached."
    echo "Refer to README_bash.md for details."
fi
