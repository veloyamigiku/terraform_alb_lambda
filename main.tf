terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.30.0"
    }
    archive = {
      source = "hashicorp/archive"
      version = "2.4.1"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "archive" {}

resource "aws_vpc" "vpc" {

  cidr_block = "12.0.0.0/16"

  tags = {
    "Name" = "vpc_for_alb_lambda"
  }
}

resource "aws_default_route_table" "drt" {
  
  default_route_table_id = aws_vpc.vpc.default_route_table_id

  route = []

  tags = {
    "Name" = "drt_for_alb_lambda"
  }
}

resource "aws_subnet" "subnet_a" {
  
  vpc_id = aws_vpc.vpc.id

  cidr_block = "12.0.1.0/24"

  # aws ec2 describe-availability-zones --output text
  availability_zone = "ap-northeast-1a"

  tags = {
    "Name" = "subnet_a_for_alb_labmda"
  }
}

resource "aws_subnet" "subnet_c" {
  
  vpc_id = aws_vpc.vpc.id

  cidr_block = "12.0.2.0/24"

  # aws ec2 describe-availability-zones --output text
  availability_zone = "ap-northeast-1c"
  
  tags = {
    "Name" = "subnet_c_for_alb_labmda"
  }
}

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.vpc.id

  tags = {
    "Name" = "igw_for_alb_lambda"
  }

}

resource "aws_route_table" "rt" {

  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    "Name" = "rt_for_alb_lambda"
  }

}

resource "aws_route_table_association" "rta_subnet_a" {

  subnet_id = aws_subnet.subnet_a.id

  route_table_id = aws_route_table.rt.id

}

resource "aws_route_table_association" "rta_subnet_c" {

  subnet_id = aws_subnet.subnet_c.id

  route_table_id = aws_route_table.rt.id
  
}

data "aws_iam_policy_document" "assume" {

  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }

}

resource "aws_iam_role" "role" {

  assume_role_policy = data.aws_iam_policy_document.assume.json

  name = "role_for_alb_lambda"

}

resource "aws_iam_role_policy_attachment" "rpa" {

  role = aws_iam_role.role.id

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

}

resource "aws_security_group" "sg" {
  name = "sg_for_alb_lambda"
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "sg_for_alb_lambda"
  }
}

resource "aws_security_group_rule" "sgr" {
  security_group_id = aws_security_group.sg.id
  type = "ingress"
  protocol = "tcp"
  from_port = 80
  to_port = 80
  cidr_blocks = [
    "0.0.0.0/0"
  ]
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/alb_lambda"
}

data "archive_file" "function_source" {
  type = "zip"
  source_dir = "app"
  output_path = "archive/my_lambda_function.zip"
}

resource "aws_lambda_function" "function" {
  function_name = "alb_lambda2"
  handler = "simple_lambda.handler"
  role = aws_iam_role.role.arn
  runtime = "python3.10"
  filename = data.archive_file.function_source.output_path
  source_code_hash = data.archive_file.function_source.output_base64sha256
  depends_on = [
    aws_iam_role_policy_attachment.rpa,
    aws_cloudwatch_log_group.lambda_log_group
    ]
  tags = {
    "Name" = "alb_lambda"
  }
}

resource "aws_lb" "lb" {
  name = "lb-for-alb-lambda"
  internal = false
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.sg.id
  ]
  subnets = [
    aws_subnet.subnet_a.id,
    aws_subnet.subnet_c.id
  ]
  tags = {
    "Name" = "lb_for_alb_lambda"
  }
}

resource "aws_lb_target_group" "ltg" {
  target_type = "lambda"
  name = "ltg-for-alb-lambda"
}

resource "aws_lb_target_group_attachment" "ltga" {
  target_group_arn = aws_lb_target_group.ltg.arn
  target_id = aws_lambda_function.function.arn
  depends_on = [
    aws_lambda_permission.lp
  ]
}

resource "aws_lambda_permission" "lp" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.function.function_name
  principal = "elasticloadbalancing.amazonaws.com"
  source_arn = aws_lb_target_group.ltg.arn
}

resource "aws_lb_listener" "lbl" {
  load_balancer_arn = aws_lb.lb.arn
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ltg.arn
  }
  port = 80
  protocol = "HTTP"
}

/*
resource "aws_lb_listener_rule" "lblr" {
  listener_arn = aws_lb_listener.lbl.arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ltg.arn
  }
  condition {
    path_pattern {
      values = [
        "/"
      ]
    }
  }
}
*/

