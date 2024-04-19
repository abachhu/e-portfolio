# ECS Cluster
resource "aws_ecs_cluster" "gen_ai_service_cluster" {
  name = local.workspace["gen_ai_cluster_name"]
}

# creating the logs
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = local.workspace["ecs_cw_log_group_name"] # CloudWatch logs name
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = local.workspace["ecs_task_role_name"]
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# allow task execution role to be assumed by ecs
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# allow task execution role to work with ecr and cw logs
resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}



# ECS Task Definition
resource "aws_ecs_task_definition" "generative_ai_service_task_definition" {
  family                   = "generative-ai-service-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"] # type of ECS cluster
  cpu                      = "256"       # CPU units
  memory                   = "512"       # Memory in MiB
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn

  container_definitions = jsonencode([{
    name      = "generative-ai-container"
    image     = "691075676085.dkr.ecr.us-east-1.amazonaws.com/gen-ai-service:docker-file-fastapi-AI-270" # ECR image URI
    cpu       = 256
    memory    = 512
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
        awslogs-region        = "us-east-1" # AWS region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

}

# ECS Service
resource "aws_ecs_service" "generative_ai_service" {
  name            = "generative-ai-service"
  cluster         = aws_ecs_cluster.gen_ai_service_cluster.arn
  task_definition = aws_ecs_task_definition.generative_ai_service_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE" # Fargate launch type

  # Scaling settings
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  network_configuration {
    subnets         = [aws_subnet.private_subnets[0].id] # Assigned to the first private subnet
    security_groups = []                                 # security groups if needed
  }
}