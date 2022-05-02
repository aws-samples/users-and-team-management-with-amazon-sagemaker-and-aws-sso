import json
import boto3
import cfnresponse
from botocore.exceptions import ClientError

ec2 = boto3.resource("ec2")

def lambda_handler(event, context):
    try:
        response_status = cfnresponse.SUCCESS
        r = {}

        if 'RequestType' in event and event['RequestType'] == 'Create':
            r["VPCCIDR"] = get_vpc_cidr(
                event['ResourceProperties']['VPCId']
            )

        cfnresponse.send(event, context, response_status, r, '')

    except ClientError as exception:
        print(exception)
        cfnresponse.send(event, context, cfnresponse.FAILED, {}, physicalResourceId=event.get('PhysicalResourceId'), reason=str(exception))

def get_vpc_cidr(vpc_id):
    print(vpc_id)

    return ec2.Vpc(vpc_id).cidr_block