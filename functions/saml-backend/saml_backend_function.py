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
from xml.dom import minidom

try:
    logger = logging.getLogger(__name__)
    logging.root.setLevel(os.environ.get("LOG_LEVEL", "INFO"))
    sm = boto3.client("sagemaker")
except Exception as e:
    print(f"Exception in initializing block: {e}")

HTTP_REDIRECT = 302
HTTP_EXCEPTION = 400
SESSION_EXPIRATION = int(os.environ.get("SESSION_EXPIRATION", 43200))
KEY_NAME_DOMAIN_ID = os.environ.get("KEY_NAME_DOMAIN_ID", "domainid")
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

def lambda_handler(event, context):
    try:
        logger.info(json.dumps(event))

        body = event.get("body")
        if not body:
            raise Exception("No body key in the request")

        attr_dict = get_saml_attributes(get_xml(body))
        domain_id = attr_dict[KEY_NAME_DOMAIN_ID]
        user_profile_name = get_user_profile_name(
            attr_dict[KEY_NAME_USER_ID],
            attr_dict[KEY_NAME_TEAM_ID]
            )

        logger.info(f"Got domain_id={domain_id} and constructed user profile name={user_profile_name}")
    
        try:
            r = sm.create_presigned_domain_url(
                DomainId=domain_id,
                UserProfileName=user_profile_name,
                SessionExpirationDurationInSeconds=SESSION_EXPIRATION,
                ExpiresInSeconds=int(os.environ.get("PRESIGNED_URL_EXPIRATION", 5))
            )

            response = {
                "statusCode": HTTP_REDIRECT,
                "headers": {
                    "Location": r["AuthorizedUrl"]
                },
                "isBase64Encoded": False
            }
            
        except botocore.exceptions.ClientError as ce:
            logger.error(f"ClientError exception in CreatePresignedDomainUrl: {ce}")
            response = {
                "statusCode": ce.response["ResponseMetadata"]["HTTPStatusCode"],
                "headers": ce.response["ResponseMetadata"]["HTTPHeaders"],
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