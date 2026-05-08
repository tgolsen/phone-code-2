variable "aws_region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "AWS account ID"
  default     = "144600480929"
}

variable "project_name" {
  description = "Project name used for resource naming"
  default     = "phone-code"
}

variable "opencode_secret_json" {
  description = "JSON string for opencode secrets (DEEPSEEK_API_KEY, etc.)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "api_key" {
  description = "API key for phone-code Lambda endpoint"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "Default GitHub token for Lambda to pass to containers"
  type        = string
  sensitive   = true
  default     = ""
}

variable "default_github_user" {
  description = "Default GitHub username"
  type        = string
  default     = ""
}

# ── VPC / Network ────────────────────────────────────────────

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ── ECR ──────────────────────────────────────────────────────

resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ── ECS Cluster ──────────────────────────────────────────────

resource "aws_ecs_cluster" "app" {
  name = var.project_name
}

# ── IAM ──────────────────────────────────────────────────────

resource "aws_iam_role" "task_execution" {
  name = "${var.project_name}-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "${var.project_name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "task_secrets" {
  name = "${var.project_name}-task-secrets"
  role = aws_iam_role.task.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.opencode.arn]
    }]
  })
}

# ── Secrets Manager ──────────────────────────────────────────

resource "aws_secretsmanager_secret" "opencode" {
  name = "${var.project_name}/opencode-api-key"
}

resource "aws_secretsmanager_secret_version" "opencode" {
  secret_id     = aws_secretsmanager_secret.opencode.id
  secret_string = var.opencode_secret_json != "" ? var.opencode_secret_json : "{}"
}

resource "aws_secretsmanager_secret" "api_key" {
  name = "${var.project_name}/api-key"
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = var.api_key
}

# ── Security Group ───────────────────────────────────────────

resource "aws_security_group" "session" {
  name        = "${var.project_name}-session"
  description = "Phone Code session containers"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 2222
    to_port     = 2222
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── ECS Task Definition ────────────────────────────────────

resource "aws_ecs_task_definition" "session" {
  family                   = "${var.project_name}-session"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name  = "${var.project_name}-session"
    image = "${aws_ecr_repository.app.repository_url}:latest"
    portMappings = [{
      containerPort = 2222
      hostPort      = 2222
      protocol      = "tcp"
    }]
    environment = [
      { name = "OPENCODE_SECRET_ARN", value = aws_secretsmanager_secret.opencode.arn },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.session.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "session"
      }
    }
  }])
}

# ── CloudWatch Logs ──────────────────────────────────────────

resource "aws_cloudwatch_log_group" "session" {
  name              = "/ecs/${var.project_name}-session"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-broker"
  retention_in_days = 7
}

# ── Lambda ───────────────────────────────────────────────────

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-broker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.project_name}-broker"
  role = aws_iam_role.lambda.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTaskDefinition",
        ]
        Resource = [
          aws_ecs_task_definition.session.arn_without_revision,
          "${aws_ecs_task_definition.session.arn_without_revision}:*",
        ]
      },
      {
        Effect = "Allow"
        Action = ["ecs:RunTask"]
        Resource = [aws_ecs_cluster.app.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks",
          "ecs:StopTask",
        ]
        Resource = [
          "${aws_ecs_cluster.app.arn}/*",
          "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:task/${aws_ecs_cluster.app.name}/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [aws_iam_role.task_execution.arn, aws_iam_role.task.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeNetworkInterfaces"]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
      },
    ]
  })
}

resource "aws_lambda_function" "broker" {
  function_name    = "${var.project_name}-broker"
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 180
  memory_size      = 256

  environment {
    variables = {
      ECS_CLUSTER          = aws_ecs_cluster.app.name
      ECS_TASK_DEFINITION  = aws_ecs_task_definition.session.family
      SUBNETS              = join(",", data.aws_subnets.default.ids)
      SECURITY_GROUP       = aws_security_group.session.id
      API_KEY              = var.api_key
      DEFAULT_GITHUB_USER  = var.default_github_user
      DEFAULT_GITHUB_TOKEN = var.github_token
      ASSIGN_PUBLIC_IP     = "true"
    }
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../session-broker"
  output_path = "${path.module}/.terraform/lambda.zip"
  excludes    = ["node_modules/.cache"]
}

# ── API Gateway ──────────────────────────────────────────────

resource "aws_apigatewayv2_api" "broker" {
  name          = "${var.project_name}-broker"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "broker" {
  api_id      = aws_apigatewayv2_api.broker.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "broker" {
  api_id           = aws_apigatewayv2_api.broker.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.broker.invoke_arn
}

resource "aws_apigatewayv2_route" "sessions" {
  api_id    = aws_apigatewayv2_api.broker.id
  route_key = "POST /sessions"
  target    = "integrations/${aws_apigatewayv2_integration.broker.id}"
}

resource "aws_apigatewayv2_route" "get_session" {
  api_id    = aws_apigatewayv2_api.broker.id
  route_key = "GET /sessions/{taskId}"
  target    = "integrations/${aws_apigatewayv2_integration.broker.id}"
}

resource "aws_apigatewayv2_route" "get_session_query" {
  api_id    = aws_apigatewayv2_api.broker.id
  route_key = "GET /sessions"
  target    = "integrations/${aws_apigatewayv2_integration.broker.id}"
}

resource "aws_apigatewayv2_route" "stop_session" {
  api_id    = aws_apigatewayv2_api.broker.id
  route_key = "DELETE /sessions/{taskId}"
  target    = "integrations/${aws_apigatewayv2_integration.broker.id}"
}

resource "aws_apigatewayv2_route" "stop_session_query" {
  api_id    = aws_apigatewayv2_api.broker.id
  route_key = "DELETE /sessions"
  target    = "integrations/${aws_apigatewayv2_integration.broker.id}"
}

resource "aws_lambda_permission" "broker" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.broker.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.broker.execution_arn}/*/*"
}

# ── Outputs ──────────────────────────────────────────────────

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.broker.api_endpoint
}

output "cluster_name" {
  value = aws_ecs_cluster.app.name
}

output "task_definition_family" {
  value = aws_ecs_task_definition.session.family
}
