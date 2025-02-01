# resource "aws_ec2_transit_gateway" "main" {
#     description = "main transit gateway"
#     provider = aws

#     tags = {
#       Name = "main draas transit gateway"
#     }
#   }

#   resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
#     subnet_ids = [aws_subnet.private.id]
#     transit_gateway_id = aws_ec2_transit_gateway.main.id
#     vpc_id = aws_vpc.main.id
#     provider = aws

#     tags = {
#       Name = "main draas tgw attachment"
#     }
#   }

#   data "aws_ec2_transit_gateway_route_table" "main" {
#     provider = aws

#     filter {
#       name   = "default-association-route-table"
#       values = ["true"]
#     }

#     filter {
#       name   = "transit-gateway-id"
#       values = [aws_ec2_transit_gateway.main.id]
#     }

#     tags = {
#       Name = "main tgw draas route table"
#     }
#   }

#   resource "aws_ec2_transit_gateway_route" "main" {
#     destination_cidr_block = var.staging_private_subnet_cidr
#     transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.main.id
#     transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.main.id
#     provider = aws
#   }

#   resource "aws_ec2_transit_gateway_peering_attachment" "main" {
#     provider = aws
#     peer_transit_gateway_id = aws_ec2_transit_gateway.dr.id
#     transit_gateway_id = aws_ec2_transit_gateway.main.id
#     peer_account_id = var.account_id
#     peer_region = var.dr_region

#     tags = {
#       Name = "main DRaws tgw peering"
#     }
#   }

# ## DR

# resource "aws_ec2_transit_gateway" "dr" {
#   provider = aws.dr
#   description = "dr transit gateway"

#   tags = {
#     Name = "dr transit draas gateway"
#   }
# }

# resource "aws_ec2_transit_gateway_vpc_attachment" "dr" {
#   provider = aws.dr
#   subnet_ids = [aws_subnet.staging_private.id]
#   transit_gateway_id = aws_ec2_transit_gateway.dr.id
#   vpc_id = aws_vpc.staging.id

#   tags = {
#     Name = "dr tgw draas attachment"
#   }
# }

# data "aws_ec2_transit_gateway_route_table" "dr" {
#   provider = aws.dr

#   filter {
#     name   = "default-association-route-table"
#     values = ["true"]
#   }

#   filter {
#     name   = "transit-gateway-id"
#     values = [aws_ec2_transit_gateway.dr.id]
#   }

#   tags = {
#     Name = "dr tgw draas route table"
#   }
# }

# resource "aws_ec2_transit_gateway_route" "dr" {
#   provider = aws.dr
#   destination_cidr_block = var.main_private_subnet_cidr
#   transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.dr.id
#   transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.dr.id
# }

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