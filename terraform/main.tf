###
### BACKEND
###
terraform {
  backend "s3" {}
}


###
### VARIABLES
###
variable "aws_region" {}
variable "aws_vpc_prefix" {}
variable "aws_vpc_cidr" {}
variable "aws_account_id" {}
variable "aws_subnets_count" {}
variable "image_region" {}
variable "image_repository" {}
variable "image_tag" {}
variable "app_name" {}
variable "app_port" {}
variable "app_cpu" {}
variable "app_memory" {}
variable "secret_region" {}
variable "secret_name" {}
variable "healthcheck_path" {}
variable "healthcheck_healthy_threshold" {}
variable "healthcheck_unhealthy_threshold" {}
variable "healthcheck_interval" {}


###
### PROVIDER
###
# AWS Provider
provider "aws" {
  region = var.aws_region
}


###
### NETWORK
###
# Listing all Availability Zones
data "aws_availability_zones" "aws-az" {
  state = "available"
}

# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name      = "${var.aws_vpc_prefix}-vpc"
    CreatedBy = "terraform"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "internet-gw" {
  vpc_id = aws_vpc.vpc.id
  
  tags = {
    Name      = "${var.aws_vpc_prefix}-internet-gw"
    CreatedBy = "terraform"
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  #count = length(data.aws_availability_zones.aws-az.names)
  count = var.aws_subnets_count
  
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index+1)
  availability_zone       = data.aws_availability_zones.aws-az.names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name      = "${data.aws_availability_zones.aws-az.names[count.index]}-public"
    CreatedBy = "terraform"
  }
}

# Create Route Table
resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gw.id
  }
  
  tags = {
    Name      = "${var.aws_vpc_prefix}-route-table-internet-gw"
    CreatedBy = "terraform"
  }
}

# Link Route Table to VPC
resource "aws_main_route_table_association" "route-table-association" {
  vpc_id         = aws_vpc.vpc.id
  route_table_id = aws_route_table.route-table.id
}


###
### SECURITY GROUP
###
resource "aws_security_group" "sg-lb" {
  name        = "${var.app_name}-sg-lb"
  description = "Allow inbound access to LB"
  vpc_id      = aws_vpc.vpc.id
  
  ingress {
    protocol    = "tcp"
    from_port   = "80"
    to_port     = "80"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name      = "${var.app_name}-sg-lb"
    CreatedBy = "terraform"
  }
}

resource "aws_security_group" "sg-task" {
  name        = "${var.app_name}-sg-task"
  description = "Allow inbound access to task definition"
  vpc_id      = aws_vpc.vpc.id
  
  ingress {
    protocol        = "tcp"
    from_port       = var.app_port
    to_port         = var.app_port
    security_groups = [aws_security_group.sg-lb.id]
  }
  
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name      = "${var.app_name}-sg-task"
    CreatedBy = "terraform"
  }
}


###
### IAM
###
# Create a custom policy to allow access only to image repository and secret variable
resource "aws_iam_role_policy" "ecs_task_execution_role_policy" {
  name = "CustomEcsTaskExecutionRolePolicy-${var.app_name}"
  role = aws_iam_role.ecs_task_execution_role.id
  
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:${var.secret_region}:${var.aws_account_id}:secret:${var.secret_name}"
    },
    {
        "Effect": "Allow",
        "Action": [
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage"
        ],
        "Resource": "arn:aws:ecr:${var.image_region}:${var.aws_account_id}:repository/${var.image_repository}"
    },
    {
        "Effect": "Allow",
        "Action": [
            "ecr:GetAuthorizationToken",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "*"
    }
  ]
}
EOF
}

# Create a IAM Role for task definition
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-${var.app_name}"
  
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


###
### CLOUDWATCH LOGS
###
# Create a cloud watch log group
resource "aws_cloudwatch_log_group" "app-log-group" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 30
}

# Create the log stream for cloud watch log group
resource "aws_cloudwatch_log_stream" "app-log-stream" {
  name           = "app-stream"
  log_group_name = aws_cloudwatch_log_group.app-log-group.name
}


###
### ECS FARGATE
###
# Create ECS Fargate Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "fargate-cluster"
  
  tags = {
    Name      = "fargate-cluster"
    CreatedBy = "terraform"
  }
}

# Read the container definition used by task definition
data "template_file" "container_definition" {
  template = file("templates/container-definition.json.tpl")
  
  vars = {
    app_name         = var.app_name
    app_image        = "${var.aws_account_id}.dkr.ecr.${var.image_region}.amazonaws.com/${var.image_repository}:${var.image_tag}"
    app_cpu          = var.app_cpu
    app_memory       = var.app_memory
    app_port         = var.app_port
    app_secret_token = "arn:aws:secretsmanager:${var.secret_region}:${var.aws_account_id}:secret:${var.secret_name}"
    awslogs_group    = "/ecs/${var.app_name}"
    awslogs_region   = var.aws_region
  }
}

# Create the app task definition using the container definition template
resource "aws_ecs_task_definition" "app-task" {
  family                   = "${var.app_name}-task"
  container_definitions    = data.template_file.container_definition.rendered
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  cpu                      = var.app_cpu
  memory                   = var.app_memory
  requires_compatibilities = ["FARGATE"]
  
  tags = {
    Name      = "${var.app_name}-task"
    CreatedBy = "terraform"
  }
}

# Create a service using the task definition created
resource "aws_ecs_service" "app-service" {
  name            = "${var.app_name}-svc"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app-task.arn
  desired_count   = "1"
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets         = aws_subnet.public.*.id
    security_groups = [aws_security_group.sg-task.id]
    assign_public_ip = true
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.lb-target-group.id
    container_name   = var.app_name
    container_port   = var.app_port
  }
  
  depends_on = [
    aws_ecs_task_definition.app-task,
    aws_lb_target_group.lb-target-group,
    aws_iam_role_policy.ecs_task_execution_role_policy
  ]
}


###
### LOAD BALANCER
###
# Create a LB instance
resource "aws_lb" "web-lb" {
  name            = "${var.app_name}-lb"
  subnets         = aws_subnet.public.*.id
  security_groups = [aws_security_group.sg-lb.id]
}

# Create a target group using ip address
resource "aws_lb_target_group" "lb-target-group" {
  name        = "${var.app_name}-lb"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"
  
  health_check {
    port                = var.app_port
    interval            = var.healthcheck_interval
    path                = var.healthcheck_path
    healthy_threshold   = var.healthcheck_healthy_threshold
    unhealthy_threshold = var.healthcheck_unhealthy_threshold
    matcher             = "200-399"
  }
  depends_on = [aws_lb.web-lb]
}

# Enabling traffic from LB to target group
resource "aws_lb_listener" "web-listener" {
  load_balancer_arn = aws_lb.web-lb.id
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    target_group_arn = aws_lb_target_group.lb-target-group.id
    type             = "forward"
  }
}


###
### OUTPUT
###
# Return service URL
output "url" {
  value = "http://${aws_lb.web-lb.dns_name}"
}