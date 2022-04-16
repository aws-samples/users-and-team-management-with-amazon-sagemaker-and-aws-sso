# Team and user management with Amazon SageMaker and SSO

## Solution overview

### Network infrastructure
This solution provisions all required network infrastructure. The CloudFormation template `./cfn-templates/vpc.yaml` contains the source code.

![](design/network-architecture.drawio.svg)



### Architecture overview

## Deployment

There are following network infrastructure deployment options:
- **New VPC**: the solution creates a new VPC with all subnets, NAT and Internet gateways, security groups, and VPC endpoints.
- **Existing VPC**: you use your existing VPC, public subnet, and NAT and Internet gateways. No one of these resources are created by the solution in this option. In this option you can choose:
    - **new private subnets**: in this case the solution creates private subnets, security groups, and VPC endpoints.
    - **use existing private subnets**: in this case the solution creates security groups and VPC endpoints only.

## Test

# Resources

## Blog posts
- [Onboarding Amazon SageMaker Studio with AWS SSO and Okta Universal Directory](https://aws.amazon.com/fr/blogs/machine-learning/onboarding-amazon-sagemaker-studio-with-aws-sso-and-okta-universal-directory/)
- [Configuring Amazon SageMaker Studio for teams and groups with complete resource isolation](https://aws.amazon.com/fr/blogs/machine-learning/configuring-amazon-sagemaker-studio-for-teams-and-groups-with-complete-resource-isolation/)
- [Secure access to Amazon SageMaker Studio with AWS SSO and a SAML application](https://aws.amazon.com/blogs/machine-learning/secure-access-to-amazon-sagemaker-studio-with-aws-sso-and-a-saml-application/)

Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0