# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import time
import boto3
import logging
import json
import cfnresponse
from botocore.exceptions import ClientError

sm_client = boto3.client('sagemaker')
logger = logging.getLogger(__name__)

def delete_user_profiles(domain_id):
    logger.info(f'Start deleting user profiles for domain id: {domain_id}')
    for p in sm_client.get_paginator('list_user_profiles').paginate(DomainIdEquals=domain_id):
      for up in p['UserProfiles']:
        if up['Status'] not in ('Deleting', 'Pending'):
          sm_client.delete_user_profile(DomainId=up['DomainId'], UserProfileName=up['UserProfileName'])

    up = 1
    while up:
        up = 0
        for p in sm_client.get_paginator('list_user_profiles').paginate(DomainIdEquals=domain_id):
            up += len([u['UserProfileName'] for u in p['UserProfiles'] if u['Status'] != 'Deleted'])
        logger.info(f'Number of active user profiles: {str(up)}')
        time.sleep(5)

def delete_apps(domain_id):    
    logger.info(f'Start deleting apps for domain id: {domain_id}')

    try:
        sm_client.describe_domain(DomainId=domain_id)
    except:
        logger.info(f'Cannot retrieve {domain_id}')
        return

    for p in sm_client.get_paginator('list_apps').paginate(DomainIdEquals=domain_id):
        for a in p['Apps']:
            if a['Status'] != 'Deleted':
                logger.info(f"Deleting {a['AppType']}:{a['AppName']}")
                sm_client.delete_app(DomainId=a['DomainId'], UserProfileName=a['UserProfileName'], AppType=a['AppType'], AppName=a['AppName'])
        
    apps = 1
    while apps:
        apps = 0
        for p in sm_client.get_paginator('list_apps').paginate(DomainIdEquals=domain_id):
            apps += len([a['AppName'] for a in p['Apps'] if a['Status'] != 'Deleted'])
        logger.info(f'Number of active apps: {str(apps)}')
        time.sleep(5)

    logger.info(f'Apps for {domain_id} deleted')
    return

def lambda_handler(event, context):
    response_data = {}
    try:
        physicalResourceId = event.get('PhysicalResourceId')

        logger.info(json.dumps(event))
    
        if event['RequestType'] in ['Create', 'Update']:
            physicalResourceId = event.get('ResourceProperties')['DomainId']
  
        elif event['RequestType'] == 'Delete':        
            delete_apps(physicalResourceId)
            delete_user_profiles(physicalResourceId)

        cfnresponse.send(event, context, cfnresponse.SUCCESS, response_data, physicalResourceId=physicalResourceId)

    except (Exception, ClientError) as exception:
        logger.error(exception)
        cfnresponse.send(event, context, cfnresponse.FAILED, response_data, physicalResourceId=physicalResourceId, reason=str(exception))