# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import os
import boto3
import logging
import json
import botocore.exceptions

try:
    logger = logging.getLogger(__name__)
    logging.root.setLevel(os.environ.get("LOG_LEVEL", "INFO"))
    sm = boto3.client("sagemaker")
except Exception as e:
    print(f"Exception in initializing block: {e}")

HTTP_REDIRECT = 302
HTTP_EXCEPTION = 400

def get_user_profile_name():
    return "not implemented"

def lambda_handler(event, context):
    try:
        logger.info(json.dumps(event))

        domain_id = "not implemented"
        user_profile_name = get_user_profile_name()
        session_expiration = 43200

        try:
            r = sm.create_presigned_domain_url(
                DomainId=domain_id,
                UserProfileName=user_profile_name,
                SessionExpirationDurationInSeconds=session_expiration,
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