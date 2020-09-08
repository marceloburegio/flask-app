# Simple Flask Application

## Setup CI/CD Pipeline

For execution of pipelines to build and push the docker image to ECR, and deploy all the infrastructure on AWS, it was used the CircleCI tool.

The following resouces were used on this application:

* AWS S3 (for Terraform State Backend)
* AWS ECR
* AWS ECS Fargate
* AWS Load Balancer
* AWS Secrets Manager

All configuration steps for pipelines was declared on .circleci folder.

Before setting all the variables, you must:

* Create a new API Access Key for terraform
* Create a new bucket for S3 backend
* Create a new container repository
* Create a Secret Manager entry (*)

(*) To create this secret manager entry, you need to choose 'Other type of secrets' and select 'Plaintext'.
Paste there the value of the secret, give it a name (without spaces) and save.
After creation, got the last part of Secret ARN to be used on 'TF_VAR_secret_name' variable.

To run properly, the following environment variables must be set up before:

Environment Variable                   | Example of Value        | Description
-------------------------------------- | ----------------------- | ---------------------------------
AWS_ACCESS_KEY_ID                      | xxxxZ7TZ                | AWS API Access Key
AWS_ACCOUNT_ID                         | xxxx12345678            | AWS Account Id number
AWS_CLI_VERSION                        | 1.18.133                | Version of AWS Cli used by pipeline
AWS_DEFAULT_REGION                     | us-east-1               | Default AWS region
AWS_SECRET_ACCESS_KEY                  | xxxxfLEI                | AWS API Secret Access Key
BACKEND_S3_STATE_BUCKET                | bucket-tf-state         | S3 Bucket name to store the TF State
BACKEND_S3_STATE_KEY                   | tf/flask-app            | Prefix path used on S3 bucket
BACKEND_S3_STATE_REGION                | us-east-1               | Region where the S3 Bucket was created
IMAGE_REGION                           | us-east-1               | Region of ECR resouce
IMAGE_REPOSITORY                       | flask-app               | Name of container image repository
TERRAFORM_VERSION                      | 0.12.29                 | Version of Terraform used by pipeline
TF_VAR_aws_vpc_prefix                  | fargate                 | Prefix name used on VPC creation
TF_VAR_aws_vpc_cidr                    | 10.0.0.0/16             | CIDR prefix designated for VPC
TF_VAR_aws_subnets_count               | 3                       | Number of public subnets created on VPC
TF_VAR_app_name                        | flask-app               | Name of application
TF_VAR_app_port                        | 8000                    | Container port
TF_VAR_app_cpu                         | 256                     | Max CPU used by container
TF_VAR_app_memory                      | 512                     | Max memory used by container
TF_VAR_secret_region                   | us-east-1               | AWS Region where the Secret Token is stored
TF_VAR_secret_name                     | app_secret_token-o7atw1 | App Secret Token name on Secrets Manager
TF_VAR_healthcheck_path                | /health                 | Application path for Health Check
TF_VAR_healthcheck_healthy_threshold   | 5                       | Health Check Healthy Threshold
TF_VAR_healthcheck_unhealthy_threshold | 2                       | Health Check Unhealthy Threshold
TF_VAR_healthcheck_interval            | 30                      | Health Check Interval


## Up and Running (Local)

To get the application up and running follow these steps:

1. Create and activate a virtual environment:

```bash
$ python -m venv venv
$ source venv/bin/activate
```

2. Install the dependencies:

```bash
$ pip install -r requirements.txt
```

3. Start the development server:

```bash
$ APP_SECRET_TOKEN=SomeSecretToken python app.py
```
