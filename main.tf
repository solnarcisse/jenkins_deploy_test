# // using ap-northeast-1
# resource "aws_resource" "resource_one" {
#   // resource configuration
# }

# // using us-east-1
# resource "aws_resource" "resource_two" {
#   provider = aws.us_east_1
#   // resource configuration
# }

data "aws_caller_identity" "current" {
  provider = aws
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  value = data.aws_caller_identity.current.arn
}

output "caller_user" {
  value = data.aws_caller_identity.current.user_id
}

data "aws_ami" "latest_linux_image" {
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

resource "aws_vpc" "VPC_A" {
  cidr_block       = "10.100.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "VPC_A"
  }
}

resource "aws_vpc" "VPC_B" {
  cidr_block       = "10.101.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "VPC_B"
  }
}

resource "aws_vpc" "VPC_C" {
  cidr_block       = "10.102.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "VPC_C"
  }
}

resource "aws_internet_gateway" "VPC_A_IGW" {
  vpc_id = aws_vpc.VPC_A.id

  tags = {
    "name" = "VPC_A_IGW"
  }
}
resource "aws_subnet" "public_subnet_1_for_VPC_A_AZ_2A" {
  vpc_id                  = aws_vpc.VPC_A.id
  cidr_block              = "10.100.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "public_subnet_1_for_VPC_A_AZ_2A"
  }
}

resource "aws_subnet" "public_subnet_2_for_VPC_A_AZ_2B" {
  vpc_id            = aws_vpc.VPC_A.id
  cidr_block        = "10.100.2.0/24"
  availability_zone = "ap-northeast-1d"
  tags = {
    Name = "public_subnet_2_for_VPC_A_AZ_2B"
  }
}


# Specify the default NACL in the first VPC


resource "aws_default_network_acl" "Default_VPC_A_NACL" {
  default_network_acl_id = aws_vpc.VPC_A.default_network_acl_id

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
    "name" = "Default_VPC_A_NACL"
  }
}


# Specify the default security group in the first VPC, and modify.
# Add an ingress rule for SSH and ICMP
# Add an egress rule for all protocols ```terraform
resource "aws_default_security_group" "SG_bastion" {
  vpc_id = aws_vpc.VPC_A.id

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


resource "aws_instance" "Bastion" {
  ami               = data.aws_ami.latest_linux_image.id
  instance_type     = "t2.micro"
  tenancy           = "default"
  availability_zone = "ap-northeast-1a"
  key_name          = ""
  subnet_id         = aws_subnet.public_subnet_1_for_VPC_A_AZ_2A.id
  security_groups   = ["${aws_default_security_group.SG_bastion.id}"]

  tags = {
    "name" = "Bastion"
  }
}


# Create a Transit gateway


resource "aws_ec2_transit_gateway" "TGW_Lab" {
  description                     = "the labs transit gateway"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name = "TGW_Lab"
  }
}


# Specify the default route table for the first VPC
# Add a route destined to all IP addresses, and a target to the Internet Gateway.
# Add a route destined to the second VPC, and a target to the Transit Gateway.
# Add a route destined to the third VPC, and a target to the Transit Gateway. ```terraform
resource "aws_default_route_table" "VPC_A_RT" {
  default_route_table_id = aws_vpc.VPC_A.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.VPC_A_IGW.id
  }

  route {
    cidr_block         = "10.101.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab.id
  }

  route {
    cidr_block         = "10.102.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab.id
  }

  tags = {
    Name = "VPC_A_RT"
  }
}

# ## Create a transit gateway attachment to the two subnets associated to the first VPC.
# ```terraform


resource "aws_ec2_transit_gateway_vpc_attachment" "TGA_VPC_A" {
  subnet_ids         = [aws_subnet.public_subnet_1_for_VPC_A_AZ_2A.id, aws_subnet.public_subnet_2_for_VPC_A_AZ_2B.id]
  transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab.id
  vpc_id             = aws_vpc.VPC_A.id

  tags = {
    Name = "TGA_VPC_A"
  }
}


# Create a first and second subnet in the second VPC
resource "aws_subnet" "public_subnet_1_for_VPC_B_AZ_2A" {
  vpc_id            = aws_vpc.VPC_B.id
  cidr_block        = "10.101.1.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "public_subnet_1_for_VPC_B_AZ_2A"
  }
}

resource "aws_subnet" "public_subnet_2_for_VPC_B_AZ_2B" {
  vpc_id            = aws_vpc.VPC_B.id
  cidr_block        = "10.101.2.0/24"
  availability_zone = "ap-northeast-1d"
  tags = {
    Name = "public_subnet_2_for_VPC_B_AZ_2B"
  }
}


# Specify the default route table for the second VPC
# Add a route destined to the first VPC, and a target to the Transit Gateway.
# Add a route destined to the third VPC, and a target to the Transit Gateway. ```terraform
resource "aws_default_route_table" "VPC_B_RT" {
  default_route_table_id = aws_vpc.VPC_B.default_route_table_id

  route {
    cidr_block         = "10.100.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab.id
  }

  route {
    cidr_block         = "10.102.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab.id
  }

  tags = {
    Name = "VPC_B_RT"
  }
}

# ## Specify the default NACL in the second VPC
# ```terraform


resource "aws_default_network_acl" "Default_VPC_B_NACL" {
  default_network_acl_id = aws_vpc.VPC_B.default_network_acl_id

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
    "name" = "Default_VPC_B_NACL"
  }
}


# Specify the default security group in the second VPC, and modify.
# Add an ingress rule for SSH and ICMP
# Add an egress rule for all protocols ```terraform
resource "aws_default_security_group" "DB_1" {
  vpc_id = aws_vpc.VPC_B.id

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


resource "aws_instance" "DB_1" {
  ami               = data.aws_ami.latest_linux_image.id
  instance_type     = "t2.micro"
  tenancy           = "default"
  availability_zone = "ap-northeast-1a"
  key_name          = ""
  subnet_id         = aws_subnet.public_subnet_1_for_VPC_B_AZ_2A.id
  security_groups   = ["${aws_default_security_group.DB_1.id}"]

  tags = {
    "name" = "DB_1"
  }
}


# Create a transit gateway attachment to the two subnets associated to the second VPC.


resource "aws_ec2_transit_gateway_vpc_attachment" "TGA_VPC_B" {
  subnet_ids         = [aws_subnet.public_subnet_1_for_VPC_B_AZ_2A.id, aws_subnet.public_subnet_2_for_VPC_B_AZ_2B.id]
  transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab.id
  vpc_id             = aws_vpc.VPC_B.id

  tags = {
    Name = "TGA_VPC_A"
  }
}


# Create a first and second subnet in the third VPC


resource "aws_subnet" "public_subnet_1_for_VPC_C_AZ_2A" {
  vpc_id            = aws_vpc.VPC_C.id
  cidr_block        = "10.102.1.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "public_subnet_1_for_VPC_C_AZ_2A"
  }
}

resource "aws_subnet" "public_subnet_2_for_VPC_C_AZ_2B" {
  vpc_id            = aws_vpc.VPC_C.id
  cidr_block        = "10.102.2.0/24"
  availability_zone = "ap-northeast-1d"
  tags = {
    Name = "public_subnet_2_for_VPC_C_AZ_2B"
  }
}


# Specify the default route table for the third VPC
# Add a route destined to the first VPC, and a target to the Transit Gateway.
# Add a route destined to the second VPC, and a target to the Transit Gateway. ```terraform
resource "aws_default_route_table" "VPC_C_RT" {
  default_route_table_id = aws_vpc.VPC_C.default_route_table_id

  route {
    cidr_block         = "10.100.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab.id
  }

  route {
    cidr_block         = "10.101.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab.id
  }

  tags = {
    Name = "VPC_C_RT"
  }
}

## Specify the default NACL in the third VPC
# ```terraform


resource "aws_default_network_acl" "Default_VPC_C_NACL" {
  default_network_acl_id = aws_vpc.VPC_C.default_network_acl_id

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
    "name" = "Default_VPC_C_NACL"
  }
}


# Specify the default security group in the third VPC, and modify.
# Add an ingress rule for SSH and ICMP
# Add an egress rule for all protocols ```terraform
resource "aws_default_security_group" "DB_2" {
  vpc_id = aws_vpc.VPC_C.id

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


resource "aws_instance" "DB_2" {
  ami               = data.aws_ami.latest_linux_image.id
  instance_type     = "t2.micro"
  tenancy           = "default"
  availability_zone = "ap-northeast-1a"
  key_name          = ""
  subnet_id         = aws_subnet.public_subnet_1_for_VPC_C_AZ_2A.id
  security_groups   = ["${aws_default_security_group.DB_2.id}"]

  tags = {
    "name" = "DB_2"
  }
}


# Create a transit gateway attachment to the two subnets associated to the third VPC.


resource "aws_ec2_transit_gateway_vpc_attachment" "TGA_VPC_C" {
  subnet_ids         = [aws_subnet.public_subnet_1_for_VPC_C_AZ_2A.id, aws_subnet.public_subnet_2_for_VPC_C_AZ_2B.id]
  transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab.id
  vpc_id             = aws_vpc.VPC_C.id

  tags = {
    Name = "TGA_VPC_C"
  }
}


# Create a Transit gateway route table for the second and third VPC
# Add a route destined to all IP addresses, which uses the first VPCs transit gateway attachment as an ingress.
# Associate the first and second transit gateway attachment to the route table so they are both used individually as egresses. ```terraform
resource "aws_ec2_transit_gateway_route_table" "TGW_RTB_VPC_B_C" {
  transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab.id

  tags = {
    "name" = "TGW_RTB_VPC_B_C"
  }
}

resource "aws_ec2_transit_gateway_route" "TGW_RTB_VPC_B_C_Route_1" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_A.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_B_C.id
}

resource "aws_ec2_transit_gateway_route_table_association" "TGW_RTB_VPC_B_C_Association_1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_B.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_B_C.id
}

resource "aws_ec2_transit_gateway_route_table_association" "TGW_RTB_VPC_B_C_Association_2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_C.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_B_C.id
}

# ## Create a Transit gateway route table for the first VPC
#    - Add two routes destined to the second and third VPC, which uses the second and third VPCs transit gateway attachment as an ingress.
#    - Associate the first transit gateway attachment to the route table, so its used as an egress.
# ```terraform


resource "aws_ec2_transit_gateway_route_table" "TGW_RTB_VPC_A" {
  transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab.id

  tags = {
    "name" = "TGW_RTB_VPC_A"
  }
}

resource "aws_ec2_transit_gateway_route" "TGW_RTB_VPC_A_Route_1" {
  destination_cidr_block         = "10.101.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_B.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_A.id
}

resource "aws_ec2_transit_gateway_route" "TGW_RTB_VPC_A_Route_2" {
  destination_cidr_block         = "10.102.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_C.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_A.id
}

resource "aws_ec2_transit_gateway_route_table_association" "TGW_RTB_VPC_A_Association_1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGA_VPC_A.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW_RTB_VPC_A.id
}


# Create an IAM Role for flow logs


# resource "aws_iam_role" "role_lab_flow_logs" {
#   name = "role_lab_flow_logs"

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
#   name = "IAM_Role_Policy_for_Flow_Log"
#   role = aws_iam_role.role_lab_flow_logs.id

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
#   name = "Transit_Gateway_Log_Group"
# }


# # Create a flow log for the first VPC


# resource "aws_flow_log" "flow_log_tgw_lab" {
#   iam_role_arn    = aws_iam_role.role_lab_flow_logs.arn
#   log_destination = aws_cloudwatch_log_group.Transit_Gateway_Log_Group.arn
#   traffic_type    = "ALL"
#   vpc_id          = aws_vpc.VPC_A.id

#   tags = {
#     Name = "flow_log_tgw_lab"
#   }
# }

# Peering attachments

resource "aws_ec2_transit_gateway_peering_attachment" "main" {
  provider                = aws
  peer_transit_gateway_id = aws_ec2_transit_gateway.TGW_Lab_East.id
  transit_gateway_id      = aws_ec2_transit_gateway.TGW_Lab.id
  peer_account_id         = data.aws_caller_identity.current.account_id
  peer_region             = "sa-east-1"

  depends_on = [aws_ec2_transit_gateway.TGW_Lab_East]

  tags = {
    Name = "main"
  }
}

# data "aws_ec2_transit_gateway_peering_attachment" "dr" {
#   provider = aws.dr
#   depends_on = [ aws_ec2_transit_gateway_peering_attachment.main ]

#   filter {
#     name = "state"
#     values = [ "pendingAcceptance" ]
#   }

#   # Only the second accepter/peer transit gateway is called from the peering attachment.
#   filter {
#     name = "transit-gateway-id"
#     values = [ aws_ec2_transit_gateway_peering_attachment.main.peer_transit_gateway_id ]
#   }
# }

# resource "aws_ec2_transit_gateway_peering_attachment_accepter" "dr" {
#   provider = aws.dr
#   transit_gateway_attachment_id = data.aws_ec2_transit_gateway_peering_attachment.dr.id 
#   tags = {
#     side = "accepter"

#   }
#   }