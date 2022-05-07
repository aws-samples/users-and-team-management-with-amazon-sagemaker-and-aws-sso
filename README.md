# Team and user management with Amazon SageMaker and AWS Single Sign-On

## Solution overview
[Amazon SageMaker Studio](https://docs.aws.amazon.com/sagemaker/latest/dg/studio-ui.html) is a web-based, integrated development environment (IDE) for machine learning (ML) that lets you build, train, debug, deploy, and monitor your ML models. Each on-boarded user in Studio has their own dedicated set of resources, such as compute instances, a home directory on an Amazon Elastic File System (EFS) volume, and a dedicated IAM execution role. 

One of the most common real-life challenges in setting up user access for Studio is how to manage multiple users, groups, and data science teams for data access and resource isolation.

Many customers implement user management using federated identities with [AWS Single Sign-On](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html) (SSO) and an external identity provider, such as Active Directory (AD) or AWS Managed Microsoft AD directory. It is aligned with AWS [best practice](https://wa.aws.amazon.com/wat.question.SEC_2.en.html) of using temporary credentials to access AWS accounts.

[Amazon SageMaker Domain](https://docs.aws.amazon.com/sagemaker/latest/dg/studio-entity-status.html) supports AWS SSO and can be configured in SSO [authentication mode](https://docs.aws.amazon.com/sagemaker/latest/dg/onboard-sso-users.html). In this case each entitled SSO user has their own [Studio user profile](https://docs.aws.amazon.com/sagemaker/latest/dg/studio-entity-status.html). Users given access to Studio have a unique sign-in URL that directly opens Studio, and they sign in with their SSO credentials. Organizations manage their users in AWS SSO instead of the SageMaker domain. You can assign multiple users access to the domain at the same time.

In SSO authentication mode, there is always **one-to-one** mapping between users and user profiles. This works well in the case when one user is a member of only one data science team. In a more common use case, when a user can participate in multiple ML projects and be member of multiple teams, the user requires access to different Studio user profiles with different execution roles and permission policies. Since you cannot manage user profiles independently of AWS SSO in SSO authentication mode, you cannot implement a one-to-many mapping between users and Studio user profiles.

The second challenge is this that [IAM-based access control](https://docs.aws.amazon.com/sagemaker/latest/dg/security_iam_id-based-policy-examples.html#api-access-policy) works only when the SageMaker domain is configured in IAM authentication mode; you can’t use it when the SageMaker domain is deployed in AWS SSO mode. 

This solution addresses a challenge of AWS SSO user management for Amazon SageMaker Studio for a common use case of multiple user groups and a many-to-many mapping between users and teams. The solution outlines how to use a[ custom SAML 2.0 application](https://docs.aws.amazon.com/singlesignon/latest/userguide/samlapps.html#addconfigcustomapp) as the mechanism to trigger the user authentication for Studio and to support multiple Studio user profiles per one AWS SSO user.

### Architecture overview
The solution implements the following architecture:

![](design/solution-architecture.drawio.svg)

The main high-level architecture components are:

**1 - Identity provider**  
Users and groups are managed in an external identity source, for example in Azure Active Directory. User assignments to AD groups define what permissions a particular user has and what SageMaker Studio "team" they have access to. The identity source must by synchronized with AWS SSO.

**2 - AWS Single Sign-On**  
AWS Single Sign-On service managed SSO users, SSO permission set, and applications. This solution uses custom SAML 2.0 application to provide access to Amazon SageMaker Studio for entitled SSO users. The solution also uses SAML attribute mapping to populate the SAML assertion with specific access-relevant data, such as SageMaker domain id, user id, and user team.

**3 - custom SAML 2.0 applications**  
The solution creates one application per SageMaker Studio user profile and assigns one or multiple applications to a user based on user entitlements. Users can access these applications from within their user portal based on assigned permissions. Each application is configured with the [Amazon API Gateway](https://aws.amazon.com/api-gateway/) endpoint URL as its SAML backend. 

**4 - Amazon SageMaker domain**  
The solution provisions a SageMaker domain in an AWS account and creates a dedicated user profile for each combination of SSO user and Studio team the user assigned to. The domain must be configured in IAM [authentication mode](https://docs.aws.amazon.com/sagemaker/latest/dg/onboard-iam.html).

**5 - Studio user profiles**  
You must provision a dedicated user profile for each _user-team_ combination For example, if a user is a member of two Studio teams and has corresponding permissions, you need to provision two separate user profiles for this user. Each profile always belongs to one and only one user.

To demonstrate the configuration, we use two users, _User 1_, _User 2_, and two Studio teams _Team 1_, _Team 2_. The _User 1_ belongs to both teams, while the _User 2_ belongs to _Team 2_ only. The _User 1_ can access Studio environments for both teams, while the _User 2_ can access only the Studio environment for _Team 2_.

**6 - Studio execution roles**  
Each Studio user profile uses a dedicated execution role with permission polices with required level of access for a specific team the user belongs to. 

The solution also implements an attribute-based access control (ABAC) using SAML 2.0 attributes, tags on Studio user profiles, and tags on SageMaker execution roles.


❗ In this particular configuration we assume that SSO users don't have permissions to log into the AWS account and don't have corresponding AWS SSO-controlled IAM roles in the account. Each user accesses the Studio environment via a presigned URL from a web browser without need to go to AWS console in the AWS account. 
In a real-life environment you might need to setup [SSO permission sets](https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html) for SSO users to allow the authorized users to assume an IAM role and log into an AWS account. For example, you can provide _Data Scientist_ role permissions for a user to be able to interact with account resources and have level of access they need to fulfill their role.

### How it works

![](design/solution-flow.drawio.svg)

### Network infrastructure
This solution provisions all required network infrastructure. The CloudFormation template `./cfn-templates/vpc.yaml` contains the source code.

![](design/network-architecture.drawio.svg)

The solution implements a fully isolated SageMaker domain environment with all network traffic going through [AWS PrivateLink](https://aws.amazon.com/privatelink) connections. You may optionally enable internet access from the Studio notebooks.

### IAM Roles

![](design/iam-roles-setup.drawio.svg)

The stack creates three SageMaker execution roles used in the SageMaker domain:
- `SageMakerStudioExecutionRoleDefault`
- `SageMakerStudioExecutionRoleTeam1`
- `SageMakerStudioExecutionRoleTeam2`

Please note, no one of the roles has [`AmazonSageMakerFullAccess`](https://docs.aws.amazon.com/sagemaker/latest/dg/security-iam-awsmanpol.html) policy attached. In your real-life SageMaker environment you need to amend role's permissions based on your specific requirements.

`SageMakerStudioExecutionRoleDefault` has only a custom policy `SageMakerReadOnlyPolicy` attached with a restrictive list of allowed actions. 

The both team roles, `SageMakerStudioExecutionRoleTeam1` and `SageMakerStudioExecutionRoleTeam2` have additionally two custom polices `SageMakerAccessSupportingServicesPolicy` and `SageMakerStudioDeveloperAccessPolicy` allowing usage of particular services and one deny-only policy `SageMakerDeniedServicesPolicy` with explicit deny on some SageMaker API calls.

The Studio developer access policy enforces the `Team` tag for calling any SageMaker `Create*` API. Furthermore, it allows using delete, stop, update, and start operations only on resources tagged with the same `Team` tag:
```json
{
    "Condition": {
        "ForAnyValue:StringEquals": {
            "aws:TagKeys": [
                "Team"
            ]
        },
        "StringEqualsIfExists": {
            "aws:RequestTag/Team": "${aws:PrincipalTag/Team}"
        }
    },
    "Action": [
        "sagemaker:Create*"
    ],
    "Resource": [
        "arn:aws:sagemaker:*:<ACCOUNT_ID>:*"
    ],
    "Effect": "Allow",
    "Sid": "AmazonSageMakerCreate"
}
```

For more information on roles and polices, refer to the blog post [Configuring Amazon SageMaker Studio for teams and groups with complete resource isolation](https://aws.amazon.com/fr/blogs/machine-learning/configuring-amazon-sagemaker-studio-for-teams-and-groups-with-complete-resource-isolation/).

## Deployment

### Prerequisites
[AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html), [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html) and [python3.8 or later](https://www.python.org/downloads/) must be installed.

The deployment procedure assumes that AWS SSO has been enabled and configured for the [AWS Organization](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_introduction.html) where the solution will be deployed.

You can follow these [instructions](./aws-sso-setup.md) to setup AWS Single Sign-On.

### Deploy solution CloudFormation stack
There are following network infrastructure deployment options:
- **New VPC**: the solution creates a new VPC with all subnets, one public and one private route tables, NAT and Internet gateways, security groups, and VPC endpoints.
- **Existing VPC**: you can use your **existing** VPC, a public subnet, and NAT and Internet gateways. No one of these resources are created by the solution in this option. If you use an existing VPC you can choose one of the following options:
    - **new private subnets**: the solution creates private subnets without internet access, a route table with a local route only, security groups, and VPC endpoints.
    - **use existing private subnets**: the solution creates security groups and VPC endpoints only.

To choose one of these deployment options, provide the following CloudFormation template parameters.

##### New VPC
- `VPCCIDR` (optional): CIDR block for a new VPC. Default is `10.0.0.0/16`
- `SAMLBackedPrivateSubnetCIDR` (optional): CIDR block for a private subnet for SAML backend. Default is `10.0.0.0/19`
- `SageMakerDomainPrivateSubnetCIDR` (optional):  CIDR block for a private subnet for SageMaker domain. Default is `10.0.32.0/19`
- `PublicSubnetCIDR` (optional): CIDR block for a public subnet for Internet and NAT Gateways. Default is `10.0.128.0/20`

❗ The provided VPC and subnet CIDR blocks must be compatible with your existing VPC and subnets. Refer to [VPC documentation](https://docs.aws.amazon.com/vpc/latest/userguide/configure-your-vpc.html#vpc-sizing-ipv4) on more details on CIDR block associations.

##### Existing VPC and new private subnets
- `ExistingVPCId` (required): Existing VPC id. You can list all VPC in your AWS account by running an AWS CLI command: 
    ```
    aws ec2 describe-vpcs
    ```
- `SAMLBackedPrivateSubnetCIDR` (required): CIDR block for a **new** private SAML backend subnet.
- `SageMakerDomainPrivateSubnetCIDR` (required): CIDR block for a **new** private subnet for SageMaker domain.

❗ The provided private subnet CIDR blocks must be compatible with your VPC and existing subnets. Refer to [VPC documentation](https://docs.aws.amazon.com/vpc/latest/userguide/configure-your-vpc.html#vpc-sizing-ipv4) on more details on CIDR block associations.
❗ The private subnets are created without internet access. The stack creates a route table with a local route only and associates this table with SAML backend and SageMaker private subnets. You must add a [route to a NAT gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html#nat-gateway-create-route) to the route table if you need an internet route for the private subnets. If you don't configure an internet route for a SageMaker private subnet, you won't have internet access in Studio notebooks.

##### Existing VPC and existing private subnets
- `ExistingVPCId` (required): Existing VPC id
- `SAMLBackedPrivateSubnetCIDR` (required): CIDR block for an **existing** subnet. The SAML backend will be created in this subnet.
- `SageMakerDomainPrivateSubnetCIDR` (required): CIDR block for an **existing** subnet for a SageMaker domain. To list all SageMaker domain subnets you can run the following AWS CLI commands:
    ```
    export DOMAIN_ID=$(aws sagemaker list-domains --output text --query 'Domains[0].DomainId')
    aws sagemaker describe-domain --domain-id $DOMAIN_ID --output text --query 'SubnetIds[*]'
    ```
❗ For this option you must use an existing SageMaker domain private subnet in the Availability Zone `a`, for example in `us-east-1a` for North Virginia AWS Region. The stack creates SageMaker API, Studio, and runtime VPC endpoints in the Availability Zone `a`.

### SageMaker domain

##### New domain

##### Existing domain
must be in `IAM` authentication mode

### Create SSO users

### Create custom SAML 2.0 applications

### Create SageMaker Studio user profiles

## Test


https://docs.aws.amazon.com/singlesignon/latest/userguide/configure-abac.html


## Synchronization with identity provider


## Access management with ABAC

# Resources

## Documentation
- [AWS Single Sign-On](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html)
- [Attributes for access control](https://docs.aws.amazon.com/singlesignon/latest/userguide/attributesforaccesscontrol.html)

## Blog posts
- [Onboarding Amazon SageMaker Studio with AWS SSO and Okta Universal Directory](https://aws.amazon.com/fr/blogs/machine-learning/onboarding-amazon-sagemaker-studio-with-aws-sso-and-okta-universal-directory/)
- [Configuring Amazon SageMaker Studio for teams and groups with complete resource isolation](https://aws.amazon.com/fr/blogs/machine-learning/configuring-amazon-sagemaker-studio-for-teams-and-groups-with-complete-resource-isolation/)
- [Secure access to Amazon SageMaker Studio with AWS SSO and a SAML application](https://aws.amazon.com/blogs/machine-learning/secure-access-to-amazon-sagemaker-studio-with-aws-sso-and-a-saml-application/)

Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0