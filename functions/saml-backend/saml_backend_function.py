# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
This is **a non-production sample** of a SAML backend
The Lambda function parses the SAML assertion and uses only attributes in `<saml2:AttributeStatement>` element to construct a `CreatePresignedDomainUrl` API call. 
In your production solution you must use a proper SAML backend implementation which must include a validation of a SAML response, a signature, and certificates, replay and redirect prevention, and any other features of a SAML authentication process. 
For example, you can use a [python3-saml SAML backend implementation](https://python-social-auth.readthedocs.io/en/latest/backends/saml.html) or 
[OneLogin open source SAML toolkit](https://developers.onelogin.com/saml/python) to implement a secure SAML backend.
"""

import json
import os
import boto3
import logging
import json
import botocore.exceptions
import base64
import urllib
import time
from xml.dom import minidom

try:
    logger = logging.getLogger(__name__)
    logging.root.setLevel(os.environ.get("LOG_LEVEL", "INFO"))
    sm = boto3.client("sagemaker")
except Exception as e:
    print(f"Exception in initializing block: {e}")

try:
    user_profile_metadata = json.loads(os.environ.get("USER_PROFILE_METADATA", "{}"))
except Exception as e:
    print(f"Exception in loading user profile metadata: {e}")

HTTP_REDIRECT = 302
HTTP_EXCEPTION = 400
KEY_NAME_USER_ID = os.environ.get("KEY_NAME_USER_ID", "ssouserid")
KEY_NAME_TEAM_ID = os.environ.get("KEY_NAME_TEAM_ID", "teamid")

def get_xml(body):
    saml_response=urllib.parse.unquote(body.split("&")[0].split("=")[1])
    return base64.b64decode(saml_response)

def get_saml_attributes(saml_response_xml):
    return {
        e.attributes["Name"].value:e.getElementsByTagName("saml2:AttributeValue")[0].childNodes[0].nodeValue 
        for e in minidom.parseString(saml_response_xml).getElementsByTagName("saml2:Attribute")
        }

def get_user_profile_name(user_id, team_id):
    return f"{user_id}-{team_id}"

def get_user_profile_metadata(team):
    """
    This function can be implemented as a microservice to return user and team metadata
    """
    return user_profile_metadata.get(team)

def create_presigned_domain_url(user_profile_name, metadata, expires_in_seconds=5):
    """
    This function can be implemented as a microservice to manage studio user profiles
    """
    user_profiles = sm.list_user_profiles(
        DomainIdEquals=metadata["DomainId"], 
        UserProfileNameContains=user_profile_name)["UserProfiles"]
    
    if len(user_profiles) > 1:
        raise Exception(f"{user_profile_name} contains in more than one user profile for domain {metadata['DomainId']}")

    if not len(user_profiles):
        r = sm.create_user_profile(
            DomainId=metadata["DomainId"],
            UserProfileName=user_profile_name,
            Tags=metadata["Tags"],
            UserSettings=metadata["UserSettings"]
        )

        while sm.describe_user_profile(
            DomainId=metadata["DomainId"],
            UserProfileName=user_profile_name)["Status"] != "InService": time.sleep(3)

    return sm.create_presigned_domain_url(
                DomainId=metadata["DomainId"],
                UserProfileName=user_profile_name,
                SessionExpirationDurationInSeconds=int(metadata["SessionExpiration"]),
                ExpiresInSeconds=expires_in_seconds
            )["AuthorizedUrl"]

def lambda_handler(event, context):
    try:
        logger.info(json.dumps(event))

        body = event.get("body")
        if not body:
            raise Exception("No body key in the request")

        attr_dict = get_saml_attributes(get_xml(body))
        user_profile_name = get_user_profile_name(
            attr_dict[KEY_NAME_USER_ID],
            attr_dict[KEY_NAME_TEAM_ID]
            )

        logger.info(f"Got team {attr_dict[KEY_NAME_TEAM_ID]} and constructed user profile name={user_profile_name}")    

        try:
            metadata = get_user_profile_metadata(attr_dict[KEY_NAME_TEAM_ID])
            if not metadata:
                raise Exception(f"no user profile metadata found for team {attr_dict[KEY_NAME_TEAM_ID]}")

            response = {
                "statusCode": HTTP_REDIRECT,
                "headers": {
                    "Location": create_presigned_domain_url(
                        user_profile_name, 
                        metadata, 
                        int(os.environ.get("PRESIGNED_URL_EXPIRATION", 5))
                    )
                },
                "isBase64Encoded": False
            }
            
        except botocore.exceptions.ClientError as ce:
            logger.error(f"ClientError exception in CreatePresignedDomainUrl: {ce}")
            response = {
                "statusCode": ce.response["ResponseMetadata"]["HTTPStatusCode"],
                "headers": {},
                "body":  ce.response["Error"]["Message"],
                "isBase64Encoded": False
            }
        except Exception as e:
            logger.error(f"Exception in CreatePresignedDomainUrl: {e}")
            response = {
                "statusCode": HTTP_EXCEPTION,
                "headers": {},
                "body": json.dumps(str(e)),
                "isBase64Encoded": False
            }
        
        return response

    except Exception as e:
        logger.error(f"Exception in function body: {e}")
        raise e