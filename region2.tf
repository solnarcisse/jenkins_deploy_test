# // using sa-east-1
# resource "aws_resource" "resource_one" {
#   // resource configuration
# }

# // using sa-east-1
# resource "aws_resource" "resource_two" {
#   provider = aws.us_east_1
#   // resource configuration
# }

# data "aws_caller_identity" "current" {}

# output "account_id_east" {
#   value = data.aws_caller_identity.current.account_id
# }

# output "caller_arn_east" {
#   value = data.aws_caller_identity.current.arn
# }

# output "caller_user_east" {
#   value = data.aws_caller_identity.current.user_id
# }

data "aws_ami" "latest_linux_image_East" {
  provider    = aws.us_east_1
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "VPC_A_East" {
  provider         = aws.us_east_1
  cidr_block       = "10.106.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "VPC_A_East"
  }
}

resource "aws_vpc" "VPC_B_East" {
  provider         = aws.us_east_1
  cidr_block       = "10.107.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "VPC_B_East"
  }
}

resource "aws_vpc" "VPC_C_East" {
  provider         = aws.us_east_1
  cidr_block       = "10.108.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "VPC_C_East"
  }
}

resource "aws_internet_gateway" "VPC_A_East_IGW" {
  provider = aws.us_east_1
  vpc_id   = aws_vpc.VPC_A_East.id

  tags = {
    "name" = "VPC_A_East_IGW"
  }
}
resource "aws_subnet" "public_subnet_1_for_VPC_A_East_AZ_2A" {
  provider                = aws.us_east_1
  vpc_id                  = aws_vpc.VPC_A_East.id
  cidr_block              = "10.106.1.0/24"
  availability_zone       = "sa-east-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "public_subnet_1_for_VPC_A_East_AZ_2A"
  }
}

resource "aws_subnet" "public_subnet_2_for_VPC_A_East_AZ_2B" {
  provider          = aws.us_east_1
  vpc_id            = aws_vpc.VPC_A_East.id
  cidr_block        = "10.106.2.0/24"
  availability_zone = "sa-east-1c"
  tags = {
    Name = "public_subnet_2_for_VPC_A_East_AZ_2B"
  }
}


# Specify the default NACL in the first VPC


resource "aws_default_network_acl" "Default_VPC_A_East_NACL" {
  provider               = aws.us_east_1
  default_network_acl_id = aws_vpc.VPC_A_East.default_network_acl_id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    "name" = "Default_VPC_A_East_NACL"
  }
}


# Specify the default security group in the first VPC, and modify.
# Add an ingress rule for SSH and ICMP
# Add an egress rule for all protocols ```terraform
resource "aws_default_security_group" "SG_Bastion_East" {
  provider = aws.us_east_1
  vpc_id   = aws_vpc.VPC_A_East.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ## Launch an instance in the first subnet, for the first VPC
# ```terraform


resource "aws_instance" "Bastion_East" {
  provider          = aws.us_east_1
  ami               = data.aws_ami.latest_linux_image_East.id
  instance_type     = "t2.micro"
  tenancy           = "default"
  availability_zone = "sa-east-1a"
  key_name          = ""
  subnet_id         = aws_subnet.public_subnet_1_for_VPC_A_East_AZ_2A.id
  security_groups   = ["${aws_default_security_group.SG_Bastion_East.id}"]

  tags = {
    "name" = "Bastion_East"
  }
}


# Create a Transit gateway


resource "aws_ec2_transit_gateway" "TGW_Lab_East" {
  provider                        = aws.us_east_1
  description                     = "the labs transit gateway"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name = "TGW_Lab_East"
  }
}


# Specify the default route table for the first VPC
# Add a route destined to all IP addresses, and a target to the Internet Gateway.
# Add a route destined to the second VPC, and a target to the Transit Gateway.
# Add a route destined to the third VPC, and a target to the Transit Gateway. ```terraform
resource "aws_default_route_table" "VPC_A_East_RT" {
  provider               = aws.us_east_1
  default_route_table_id = aws_vpc.VPC_A_East.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.VPC_A_East_IGW.id
  }

  route {
    cidr_block         = "10.107.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id
  }

  route {
    cidr_block         = "10.108.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id
  }

  tags = {
    Name = "VPC_A_East_RT"
  }
}

# ## Create a transit gateway attachment to the two subnets associated to the first VPC.
# ```terraform


resource "aws_ec2_transit_gateway_vpc_attachment" "TGA_VPC_A_East" {
  provider           = aws.us_east_1
  subnet_ids         = [aws_subnet.public_subnet_1_for_VPC_A_East_AZ_2A.id, aws_subnet.public_subnet_2_for_VPC_A_East_AZ_2B.id]
  transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id
  vpc_id             = aws_vpc.VPC_A_East.id

  tags = {
    Name = "TGA_VPC_A_East"
  }
}


# Create a first and second subnet in the second VPC
resource "aws_subnet" "public_subnet_1_for_VPC_B_East_AZ_2A" {
  provider          = aws.us_east_1
  vpc_id            = aws_vpc.VPC_B_East.id
  cidr_block        = "10.107.1.0/24"
  availability_zone = "sa-east-1a"
  tags = {
    Name = "public_subnet_1_for_VPC_B_East_AZ_2A"
  }
}

resource "aws_subnet" "public_subnet_2_for_VPC_B_East_AZ_2B" {
  provider          = aws.us_east_1
  vpc_id            = aws_vpc.VPC_B_East.id
  cidr_block        = "10.107.2.0/24"
  availability_zone = "sa-east-1c"
  tags = {
    Name = "public_subnet_2_for_VPC_B_East_AZ_2B"
  }
}


# Specify the default route table for the second VPC
# Add a route destined to the first VPC, and a target to the Transit Gateway.
# Add a route destined to the third VPC, and a target to the Transit Gateway. ```terraform
resource "aws_default_route_table" "VPC_B_East_RT" {
  provider               = aws.us_east_1
  default_route_table_id = aws_vpc.VPC_B_East.default_route_table_id

  route {
    cidr_block         = "10.106.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id
  }

  route {
    cidr_block         = "10.108.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id
  }

  tags = {
    Name = "VPC_B_East_RT"
  }
}

# ## Specify the default NACL in the second VPC
# ```terraform


resource "aws_default_network_acl" "Default_VPC_B_East_NACL" {
  provider               = aws.us_east_1
  default_network_acl_id = aws_vpc.VPC_B_East.default_network_acl_id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    "name" = "Default_VPC_B_East_NACL"
  }
}


# Specify the default security group in the second VPC, and modify.
# Add an ingress rule for SSH and ICMP
# Add an egress rule for all protocols ```terraform
resource "aws_default_security_group" "DB_EAST_1" {
  provider = aws.us_east_1
  vpc_id   = aws_vpc.VPC_B_East.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ## Launch an instance in the first subnet, for the second VPC
# ```terraform


resource "aws_instance" "DB_EAST_1" {
  provider          = aws.us_east_1
  ami               = data.aws_ami.latest_linux_image_East.id
  instance_type     = "t2.micro"
  tenancy           = "default"
  availability_zone = "sa-east-1a"
  key_name          = ""
  subnet_id         = aws_subnet.public_subnet_1_for_VPC_B_East_AZ_2A.id
  security_groups   = ["${aws_default_security_group.DB_EAST_1.id}"]

  tags = {
    "name" = "DB_EAST_1"
  }
}


# Create a transit gateway attachment to the two subnets associated to the second VPC.


resource "aws_ec2_transit_gateway_vpc_attachment" "TGA_VPC_B_East" {
  provider           = aws.us_east_1
  subnet_ids         = [aws_subnet.public_subnet_1_for_VPC_B_East_AZ_2A.id, aws_subnet.public_subnet_2_for_VPC_B_East_AZ_2B.id]
  transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id
  vpc_id             = aws_vpc.VPC_B_East.id

  tags = {
    Name = "TGA_VPC_A_East"
  }
}


# Create a first and second subnet in the third VPC


resource "aws_subnet" "public_subnet_1_for_VPC_C_East_AZ_2A" {
  provider          = aws.us_east_1
  vpc_id            = aws_vpc.VPC_C_East.id
  cidr_block        = "10.108.1.0/24"
  availability_zone = "sa-east-1a"
  tags = {
    Name = "public_subnet_1_for_VPC_C_East_AZ_2A"
  }
}

resource "aws_subnet" "public_subnet_2_for_VPC_C_East_AZ_2B" {
  provider          = aws.us_east_1
  vpc_id            = aws_vpc.VPC_C_East.id
  cidr_block        = "10.108.2.0/24"
  availability_zone = "sa-east-1c"
  tags = {
    Name = "public_subnet_2_for_VPC_C_East_AZ_2B"
  }
}


# Specify the default route table for the third VPC
# Add a route destined to the first VPC, and a target to the Transit Gateway.
# Add a route destined to the second VPC, and a target to the Transit Gateway. ```terraform
resource "aws_default_route_table" "VPC_C_East_RT" {
  provider               = aws.us_east_1
  default_route_table_id = aws_vpc.VPC_C_East.default_route_table_id

  route {
    cidr_block         = "10.106.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id
  }

  route {
    cidr_block         = "10.107.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id
  }

  tags = {
    Name = "VPC_C_East_RT"
  }
}

## Specify the default NACL in the third VPC
# ```terraform


resource "aws_default_network_acl" "Default_VPC_C_East_NACL" {
  provider               = aws.us_east_1
  default_network_acl_id = aws_vpc.VPC_C_East.default_network_acl_id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    "name" = "Default_VPC_C_East_NACL"
  }
}


# Specify the default security group in the third VPC, and modify.
# Add an ingress rule for SSH and ICMP
# Add an egress rule for all protocols ```terraform
resource "aws_default_security_group" "DB_EAST_2" {
  provider = aws.us_east_1
  vpc_id   = aws_vpc.VPC_C_East.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ## Launch an instance in the first subnet, for the third VPC
# ```terraform


resource "aws_instance" "DB_EAST_2" {
  provider          = aws.us_east_1
  ami               = data.aws_ami.latest_linux_image_East.id
  instance_type     = "t2.micro"
  tenancy           = "default"
  availability_zone = "sa-east-1a"
  key_name          = ""
  subnet_id         = aws_subnet.public_subnet_1_for_VPC_C_East_AZ_2A.id
  security_groups   = ["${aws_default_security_group.DB_EAST_2.id}"]

  tags = {
    "name" = "DB_EAST_2"
  }
}


# Create a transit gateway attachment to the two subnets associated to the third VPC.


resource "aws_ec2_transit_gateway_vpc_attachment" "TGA_VPC_C_East" {
  provider           = aws.us_east_1
  subnet_ids         = [aws_subnet.public_subnet_1_for_VPC_C_East_AZ_2A.id, aws_subnet.public_subnet_2_for_VPC_C_East_AZ_2B.id]
  transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id
  vpc_id             = aws_vpc.VPC_C_East.id

  tags = {
    Name = "TGA_VPC_C_East"
  }
}


# Create a Transit gateway route table for the second and third VPC
# Add a route destined to all IP addresses, which uses the first VPCs transit gateway attachment as an ingress.
# Associate the first and second transit gateway attachment to the route table so they are both used individually as egresses. ```terraform
resource "aws_ec2_transit_gateway_route_table" "TGW_RTB_VPC_B_East_C" {
  provider           = aws.us_east_1
  transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id

  tags = {
    "name" = "TGW_RTB_VPC_B_East_C"
  }
}

resource "aws_ec2_transit_gateway_route" "TGW_RTB_VPC_B_East_C_Route_1" {
  provider                       = aws.us_east_1
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_A_East.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_B_East_C.id
}

resource "aws_ec2_transit_gateway_route_table_association" "TGW_RTB_VPC_B_East_C_Association_1" {
  provider                       = aws.us_east_1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_B_East.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_B_East_C.id
}

resource "aws_ec2_transit_gateway_route_table_association" "TGW_RTB_VPC_B_East_C_Association_2" {
  provider                       = aws.us_east_1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_C_East.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_B_East_C.id
}

# ## Create a Transit gateway route table for the first VPC
#    - Add two routes destined to the second and third VPC, which uses the second and third VPCs transit gateway attachment as an ingress.
#    - Associate the first transit gateway attachment to the route table, so its used as an egress.
# ```terraform


resource "aws_ec2_transit_gateway_route_table" "TGW_RTB_VPC_A_East" {
  provider           = aws.us_east_1
  transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id

  tags = {
    "name" = "TGW_RTB_VPC_A_East"
  }
}

resource "aws_ec2_transit_gateway_route" "TGW_RTB_VPC_A_East_Route_1" {
  provider                       = aws.us_east_1
  destination_cidr_block         = "10.107.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_B_East.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_A_East.id
}

resource "aws_ec2_transit_gateway_route" "TGW_RTB_VPC_A_East_Route_2" {
  provider                       = aws.us_east_1
  destination_cidr_block         = "10.108.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_C_East.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_A_East.id
}

resource "aws_ec2_transit_gateway_route_table_association" "TGW_RTB_VPC_A_East_Association_1" {
  provider                       = aws.us_east_1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_A_East.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_A_East.id
}


# # Create an IAM Role for flow logs


# resource "aws_iam_role" "role_lab_flow_logs" {
#   provider = aws.us_east_1
#   name     = "role_lab_flow_logs"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "",
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "vpc-flow-logs.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOF
# }


# # Create an IAM Role policy for flow logs


# resource "aws_iam_role_policy" "IAM_Role_Policy_for_Flow_Log" {
#   provider = aws.us_east_1
#   name     = "IAM_Role_Policy_for_Flow_Log"
#   role     = aws_iam_role.role_lab_flow_logs.id

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": [
#         "logs:CreateLogGroup",
#         "logs:CreateLogStream",
#         "logs:PutLogEvents",
#         "logs:DescribeLogGroups",
#         "logs:DescribeLogStreams"
#       ],
#       "Effect": "Allow",
#       "Resource": "*"
#     }
#   ]
# }
# EOF
# }


# # Create a Cloudwatch log group


# resource "aws_cloudwatch_log_group" "Transit_Gateway_Log_Group" {
#   provider = aws.us_east_1
#   name     = "Transit_Gateway_Log_Group"
# }


# # Create a flow log for the first VPC


# resource "aws_flow_log" "flow_log_TGW_Lab_East" {
#   provider        = aws.us_east_1
#   iam_role_arn    = aws_iam_role.role_lab_flow_logs.arn
#   log_destination = aws_cloudwatch_log_group.Transit_Gateway_Log_Group.arn
#   traffic_type    = "ALL"
#   vpc_id          = aws_vpc.VPC_A_East.id

#   tags = {
#     Name = "flow_log_tgw_lab_east"
#   }
# }

# Peering attachments

# resource "aws_ec2_transit_gateway_peering_attachment" "main_east" {
#   provider                = aws.us_east_1
#   peer_transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id
#   transit_gateway_id      = aws_ec2_transit_gateway.TGW_Lab.id
#   peer_account_id         = data.aws_caller_identity.current.account_id
#   peer_region             = "ap-northeast-1"
#   depends_on = [aws_ec2_transit_gateway_peering_attachment.main]


#   tags = {
#     Name = "main_east"
#   }
# }

data "aws_caller_identity" "current_east" {
  provider = aws.us_east_1
}

output "account_id_east" {
  value = data.aws_caller_identity.current_east.account_id
}

output "caller_arn_east" {
  value = data.aws_caller_identity.current_east.arn
}

output "caller_user_east" {
  value = data.aws_caller_identity.current_east.user_id
}

data "aws_ec2_transit_gateway_peering_attachment" "main" {
  provider   = aws
  depends_on = [aws_ec2_transit_gateway_peering_attachment.main]

  filter {
    name   = "state"
    values = ["pendingAcceptance", "available"]
  }

  # Only the second accepter/peer transit gateway is called from the peering attachment.
  filter {
    name   = "transit-gateway-id"
    values = [aws_ec2_transit_gateway_peering_attachment.main.transit_gateway_id]
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "main_east_peer_attach_Accept" {
  provider                      = aws.us_east_1
  transit_gateway_attachment_id = data.aws_ec2_transit_gateway_peering_attachment.main.id
  tags = {
    side = "accepter"

  }
}