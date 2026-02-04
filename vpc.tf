# VPC for SageMaker Domain in us-east-1
resource "aws_vpc" "application_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.application_vpc.id

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-igw"
    }
  )
}

# Public Subnets (for NAT Gateway)
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.application_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-public-subnet-1"
    }
  )
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.application_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-public-subnet-2"
    }
  )
}

# Private Subnets (for SageMaker)
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.application_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-private-subnet-1"
    }
  )
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.application_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1b"

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-private-subnet-2"
    }
  )
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_1" {
  domain = "vpc"

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-nat-eip-1"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "nat_2" {
  domain = "vpc"

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-nat-eip-2"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-nat-gateway-1"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.public_subnet_2.id

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-nat-gateway-2"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.application_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-public-rt"
    }
  )
}

# Private Route Tables
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.application_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1.id
  }

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-private-rt-1"
    }
  )
}

resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.application_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_2.id
  }

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-private-rt-2"
    }
  )
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_2.id
}

# VPC Endpoints for SageMaker
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.application_vpc.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_1.id, aws_route_table.private_2.id]

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-s3-endpoint"
    }
  )
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.application_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.application_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "vpc-endpoints-sg"
    }
  )
}

resource "aws_vpc_endpoint" "sagemaker_api" {
  vpc_id              = aws_vpc.application_vpc.id
  service_name        = "com.amazonaws.us-east-1.sagemaker.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-sagemaker-api-endpoint"
    }
  )
}

resource "aws_vpc_endpoint" "sagemaker_runtime" {
  vpc_id              = aws_vpc.application_vpc.id
  service_name        = "com.amazonaws.us-east-1.sagemaker.runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "application-sagemaker-runtime-endpoint"
    }
  )
}
