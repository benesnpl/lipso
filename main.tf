provider "aws" {
  region = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

resource "aws_ec2_transit_gateway" "main_tgw" {
  description = "TGW"
  auto_accept_shared_attachments = "enable"
  tags = {
   Name = join("", [var.coid, "-TGW"])
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-main" {
  depends_on = [aws_ec2_transit_gateway.main_tgw]
  subnet_ids         = [var.tgw-sub1,var.tgw-sub2]
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = var.vpc_cidr
  appliance_mode_support = "enable"
  tags = {
   Name = join("", [var.coid, "-SecVPC"])
  }
}

resource "aws_internet_gateway" "main_igw" {
  depends_on = [aws_ec2_transit_gateway.main_tgw,aws_internet_gateway.main_igw]
  vpc_id = var.vpc_cidr
  tags = {
    Name = join("", [var.coid, "-IGW"])
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = var.vpc_cidr
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
  
  
  tags = {
    Name = ("Public-rt")
  }
}

resource "aws_route_table_association" "public" {
  depends_on = [aws_route_table.public_rt]
  subnet_id      = var.pub-sub1
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public2" {
  depends_on = [aws_route_table.public_rt]
  subnet_id      = var.pub-sub2
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_customer_gateway" "oakbrook" {
  bgp_asn    = 65000
  ip_address = var.il_external
  type       = "ipsec.1"

  tags = {
    Name = join("", [var.coid, "-Oakbrook-CGW"])
  }
}

resource "aws_customer_gateway" "miami" {
  bgp_asn    = 65000
  ip_address = var.fl_external
  type       = "ipsec.1"

  tags = {
    Name = join("", [var.coid, "-Miami-CGW"])
  }
} 

  resource "aws_vpn_connection" "Oakbrook" {
  transit_gateway_id  = aws_ec2_transit_gateway.main_tgw.id
  customer_gateway_id = aws_customer_gateway.oakbrook.id
  type                = "ipsec.1"
  static_routes_only  = true
  tags = {
    Name = join("", [var.coid, "-Oakbrook-ipsec"])
  }
  
}

resource "aws_vpn_connection" "Miami" {
  transit_gateway_id  = aws_ec2_transit_gateway.main_tgw.id
  customer_gateway_id = aws_customer_gateway.miami.id
  type                = "ipsec.1"
  static_routes_only  = true
  tags = {
    Name = join("", [var.coid, "-Miami-ipsec"])
  }
}

data "aws_ec2_transit_gateway_vpn_attachment" "oak_attach" {
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpn_connection_id  = aws_vpn_connection.Oakbrook.id
}

data "aws_ec2_transit_gateway_vpn_attachment" "miami_attach" {
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpn_connection_id  = aws_vpn_connection.Miami.id
}

resource "aws_ec2_transit_gateway_route" "oak_vpn" {
  destination_cidr_block         = "10.159.94.0/23"
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpn_attachment.oak_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.main_tgw.association_default_route_table_id
  blackhole                      = false
}

resource "aws_ec2_transit_gateway_route" "mia_vpn" {
  destination_cidr_block         = "10.189.0.0/23"
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpn_attachment.miami_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.main_tgw.association_default_route_table_id
  blackhole                      = false
}

resource "aws_route_table" "private_rt" {
  depends_on = [aws_internet_gateway.main_igw,aws_ec2_transit_gateway.main_tgw,aws_vpn_connection.Miami]
  vpc_id = var.vpc_cidr
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_ec2_transit_gateway.main_tgw.id
  }
  
  
  tags = {
    Name = ("Private-rt")
  }
}

resource "aws_route_table_association" "prvt" {
  depends_on = [aws_route_table.private_rt]
  subnet_id      = var.prv-sub1
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "prvt3" {
  depends_on = [aws_route_table.private_rt]
  subnet_id      = var.prv-sub2
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "prvt2" {
  depends_on = [aws_route_table.private_rt]
  subnet_id      = var.gwlb-sub1
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "prvt4" {
  depends_on = [aws_route_table.private_rt]
  subnet_id      = var.gwlb-sub2
  route_table_id = aws_route_table.private_rt.id
  
resource "aws_route_table" "gwlbe_rt" {
  depends_on = [aws_ec2_transit_gateway.main_tgw,aws_vpn_connection.Miami]
  vpc_id = var.vpc_cidr
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_ec2_transit_gateway.main_tgw.id
  }
  
  
  tags = {
    Name = ("GWLBE-rt")
  }
}

resource "aws_route_table_association" "gwlbe" {
  depends_on = [aws_route_table.gwlbe_rt,aws_ec2_transit_gateway.main_tgw,aws_route_table.gwlbe_rt]
  subnet_id      = var.gwlbe-sub1
  route_table_id = aws_route_table.gwlbe_rt.id
}

resource "aws_route_table_association" "gwlbe2" {
  depends_on = [aws_route_table.gwlbe_rt,aws_ec2_transit_gateway.main_tgw,aws_route_table.gwlbe_rt]
  subnet_id      = var.gwlbe-sub2
  route_table_id = aws_route_table.gwlbe_rt.id
}
