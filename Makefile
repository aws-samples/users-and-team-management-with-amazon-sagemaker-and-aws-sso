# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#SHELL := /bin/sh
PY_VERSION := 3.8

export PYTHONUNBUFFERED := 1

SRC_DIR := functions
TEST_DIR := test
SAM_DIR := .aws-sam
TEMPLATE_DIR := .
TESTAPP_DIR := test/integration/testdata/

# user can optionally override the following by setting environment variables with the same names before running make

# Path to system pip
PIP ?= pip
# Region for deployment
AWS_DEPLOY_REGION ?= us-east-1
# Region for publishing
AWS_PUBLISH_REGION ?= us-east-1
# Stack name
APP_STACK_NAME ?= sagemaker-team-mgmt-sso
# S3 bucket used for packaging SAM templates
PACKAGE_BUCKET ?= $(APP_STACK_NAME)-$(AWS_DEPLOY_REGION)

PYTHON := $(shell /usr/bin/which python$(PY_VERSION))

.DEFAULT_GOAL := build

ifndef PACKAGE_BUCKET
$(error PACKAGE_BUCKET is not set)
endif 

compile:
	pipenv run sam build -p -t $(TEMPLATE_DIR)/template.yaml -m $(SRC_DIR)/requirements.txt

build: compile

package: compile
	pipenv run sam package --template-file $(SAM_DIR)/build/template.yaml --s3-bucket $(PACKAGE_BUCKET) --output-template-file $(SAM_DIR)/packaged.yaml

publish: package
	pipenv run sam publish --template $(SAM_DIR)/packaged.yaml --region $(AWS_PUBLISH_REGION)

# need to add CAPABILITY_AUTO_EXPAND to be able to update nested stack (aws-lambda-powertools-python-layer)
deploy: package
	pipenv run sam deploy --template-file $(SAM_DIR)/packaged.yaml \
						  --stack-name $(APP_STACK_NAME) \
						  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
						  --region $(AWS_DEPLOY_REGION) \
						  --confirm-changeset 

cfn_nag_scan: 
	cfn_nag_scan --input-path $(TEMPLATE_DIR)
