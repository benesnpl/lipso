provider "aws" {
  region = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

resource "aws_vpc" "main_vpc" {
  cidr_block       					         = var.vpc_cidr
  tags = {
    Name = join("", [var.coid, "-VPC"])
  }
}

resource "aws_subnet" "public" {
  count = length(var.subnets_cidr_public)
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = element(var.subnets_cidr_public,count.index)
  availability_zone = element(var.azs,count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = ("Public-AZ${count.index+1}")
  }
}

resource "aws_subnet" "Private" {
  count = length(var.subnets_cidr_private)
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = element(var.subnets_cidr_private,count.index)
  availability_zone = element(var.azs,count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = ("Private-AZ${count.index+1}")
  }
}

resource "aws_subnet" "MNG" {
  count = length(var.subnets_cidr_mng)
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = element(var.subnets_cidr_mng,count.index)
  availability_zone = element(var.azs,count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = ("MNG-AZ${count.index+1}")
  }
}

resource "aws_subnet" "TGW" {
  count = length(var.subnets_cidr_tgw)
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = element(var.subnets_cidr_tgw,count.index)
  availability_zone = element(var.azs,count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = ("TGW-AZ${count.index+1}")
  }
}

resource "aws_subnet" "GWLB" {
  count = length(var.subnets_cidr_gwlb)
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = element(var.subnets_cidr_gwlb,count.index)
  availability_zone = element(var.azs,count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = ("GWLB-AZ${count.index+1}")
  }
}

resource "aws_subnet" "GWLBE" {
  count = length(var.subnets_cidr_gwlbe)
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = element(var.subnets_cidr_gwlbe,count.index)
  availability_zone = element(var.azs,count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = ("GWLBE-AZ${count.index+1}")
  }
}


resource "aws_ec2_transit_gateway" "main_tgw" {
  description = "TGW"
  auto_accept_shared_attachments = "enable"
  tags = {
   Name = join("", [var.coid, "-TGW"])
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-main" {
  depends_on = [aws_subnet.TGW,aws_ec2_transit_gateway.main_tgw]
  subnet_ids         = "${aws_subnet.TGW.*.id}"
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = aws_vpc.main_vpc.id
  appliance_mode_support = "enable"
  tags = {
   Name = join("", [var.coid, "-SecVPC"])
  }
}

resource "aws_internet_gateway" "main_igw" {
  depends_on = [aws_ec2_transit_gateway.main_tgw,aws_internet_gateway.main_igw]
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = join("", [var.coid, "-IGW"])
  }
}

resource "aws_route_table" "mgmt_rt" {
  depends_on = [aws_internet_gateway.main_igw,aws_ec2_transit_gateway.main_tgw,aws_vpn_connection.Miami]
  vpc_id = aws_vpc.main_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
  
  route {
    cidr_block = "10.159.94.0/23"
    gateway_id = aws_ec2_transit_gateway.main_tgw.id
  }
  
   route {
    cidr_block = "100.70.0.0/15"
    gateway_id = aws_ec2_transit_gateway.main_tgw.id
  }
  
  tags = {
    Name = ("mgmt-rt")
  }
}

resource "aws_route_table_association" "mgmt" {
  depends_on = [aws_route_table.mgmt_rt,aws_ec2_transit_gateway.main_tgw]
  count = length(var.subnets_cidr_mng)
  subnet_id      = element(aws_subnet.MNG.*.id,count.index)
  route_table_id = aws_route_table.mgmt_rt.id
}


resource "aws_route_table" "private_rt" {
  depends_on = [aws_internet_gateway.main_igw,aws_ec2_transit_gateway.main_tgw,aws_vpn_connection.Miami]
  vpc_id = aws_vpc.main_vpc.id
  
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
  count = length(var.subnets_cidr_private)
  subnet_id      = element(aws_subnet.Private.*.id,count.index)
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "prvt2" {
  depends_on = [aws_route_table.private_rt]
  count = length(var.subnets_cidr_gwlb)
  subnet_id      = element(aws_subnet.GWLB.*.id,count.index)
  route_table_id = aws_route_table.private_rt.id
}


resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  
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
  count = length(var.subnets_cidr_public)
  subnet_id      = element(aws_subnet.public.*.id,count.index)
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "gwlbe_rt" {
  depends_on = [aws_ec2_transit_gateway.main_tgw,aws_vpn_connection.Miami]
  vpc_id = aws_vpc.main_vpc.id
  
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
  count = length(var.subnets_cidr_gwlbe)
  subnet_id      = element(aws_subnet.GWLBE.*.id,count.index)
  route_table_id = aws_route_table.gwlbe_rt.id
}


resource "aws_lb" "gwlb" {
  depends_on 					   = [aws_subnet.GWLB]
  name                             = "GWLB-Private"
  load_balancer_type               = "gateway"
  enable_cross_zone_load_balancing = true
  subnets                          = [for subnet in aws_subnet.GWLB : subnet.id]
}


resource "aws_vpc_endpoint_service" "vpc_end_serv" {
  depends_on = [aws_lb.gwlb]
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]
  tags = {
    Name = ("VPCE-GWLB")
  }
}

  resource "aws_lb_target_group" "tgt_group" {
  name                 = "GWLB-Group"
  vpc_id               = aws_vpc.main_vpc.id
  target_type          = "ip"
  protocol             = "GENEVE"
  port                 = "6081"

  health_check {
    enabled             = true
    interval            = 5
    path                = "/php/login.php"
    port                = 443
    protocol            = "HTTPS"
  }
}

  resource "aws_lb_target_group_attachment" "register-tgp1" {
  depends_on       = [aws_lb_target_group.tgt_group]
  target_group_arn = aws_lb_target_group.tgt_group.arn
  target_id        = var.lb_target_1
  port             = 6081
}

  resource "aws_lb_target_group_attachment" "register-tgp2" {
  depends_on       = [aws_lb_target_group.tgt_group]
  target_group_arn = aws_lb_target_group.tgt_group.arn
  target_id        = var.lb_target_1
  port             = 6081
}


 resource "aws_lb_listener" "listener" {
  depends_on       = [aws_lb_target_group_attachment.register-tgp2,aws_lb_target_group_attachment.register-tgp2]
  load_balancer_arn = aws_lb.gwlb.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tgt_group.arn
  }
}

resource "aws_vpc_endpoint" "az1" {
  service_name      = aws_vpc_endpoint_service.vpc_end_serv.service_name
  subnet_ids        = [aws_subnet.GWLBE[0].id]
  vpc_endpoint_type = aws_vpc_endpoint_service.vpc_end_serv.service_type
  vpc_id            = aws_vpc.main_vpc.id
  tags = {
    Name = ("Security-AZ1")
  }
}

resource "aws_vpc_endpoint" "az2" {
  service_name      = aws_vpc_endpoint_service.vpc_end_serv.service_name
  subnet_ids        = [aws_subnet.GWLBE[1].id]
  vpc_endpoint_type = aws_vpc_endpoint_service.vpc_end_serv.service_type
  vpc_id            = aws_vpc.main_vpc.id
  tags = {
    Name = ("Security-AZ2")
  }
}

resource "aws_route_table" "tgw1_rt" {
  depends_on = [aws_vpc_endpoint.az1]
  vpc_id = aws_vpc.main_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.az1.id
  }
  
  
  tags = {
    Name = ("TGW-AZ1-rt")
  }
}

resource "aws_route_table_association" "tgw1" {
  depends_on = [aws_route_table.tgw1_rt]
  subnet_id      =aws_subnet.TGW[0].id
  route_table_id = aws_route_table.tgw1_rt.id
}


resource "aws_route_table" "tgw2_rt" {
  depends_on = [aws_vpc_endpoint.az2]
  vpc_id = aws_vpc.main_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.az2.id
  }
  
  
  tags = {
    Name = ("TGW-AZ2-rt")
  }
}

resource "aws_route_table_association" "tgw2" {
  depends_on = [aws_route_table.tgw2_rt]
  subnet_id      =aws_subnet.TGW[1].id
  route_table_id = aws_route_table.tgw2_rt.id
}

  resource "aws_security_group" "public_sg" {
  name        = "public_sg"
  description = "public SG"
  vpc_id      = aws_vpc.main_vpc.id

  dynamic "ingress" {
    for_each = var.rules_inbound_public_sg
    content {
      from_port = ingress.value["port"]
      to_port = ingress.value["port"]
      protocol = ingress.value["proto"]
      cidr_blocks = ingress.value["cidr_block"]
    }
  }
  dynamic "egress" {
    for_each = var.rules_outbound_public_sg
    content {
      from_port = egress.value["port"]
      to_port = egress.value["port"]
      protocol = egress.value["proto"]
      cidr_blocks = egress.value["cidr_block"]
    }
  }
  tags = {
    Name = join("", [var.coid, "-Public-sg"])
  }
}

 resource "aws_security_group" "private_sg" {
  name        = "private_sg"
  description = "Private SG"
  vpc_id      = aws_vpc.main_vpc.id

  dynamic "ingress" {
    for_each = var.rules_inbound_private_sg
    content {
      from_port = ingress.value["port"]
      to_port = ingress.value["port"]
      protocol = ingress.value["proto"]
      cidr_blocks = ingress.value["cidr_block"]
    }
  }
  dynamic "egress" {
    for_each = var.rules_outbound_private_sg
    content {
      from_port = egress.value["port"]
      to_port = egress.value["port"]
      protocol = egress.value["proto"]
      cidr_blocks = egress.value["cidr_block"]
    }
  }
  tags = {
    Name = join("", [var.coid, "-Private-sg"])
  }
} 

  resource "aws_security_group" "MGMT_sg" {
  name        = "MGMT_sg"
  description = "MGMT SG"
  vpc_id      = aws_vpc.main_vpc.id

  dynamic "ingress" {
    for_each = var.rules_inbound_mgmt_sg
    content {
      from_port = ingress.value["port"]
      to_port = ingress.value["port"]
      protocol = ingress.value["proto"]
      cidr_blocks = ingress.value["cidr_block"]
    }
  }
  dynamic "egress" {
    for_each = var.rules_outbound_mgmt_sg
    content {
      from_port = egress.value["port"]
      to_port = egress.value["port"]
      protocol = egress.value["proto"]
      cidr_blocks = egress.value["cidr_block"]
    }
  }
  tags = {
    Name = join("", [var.coid, "-MGMT-sg"])
  }
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

 resource "aws_customer_gateway" "ny" {
  bgp_asn    = 65302
  ip_address = var.ny_ip
  type       = "ipsec.1"

  tags = {
    Name = join("", [var.coid, "-NewYork-CGW"])
  }
}

resource "aws_customer_gateway" "virginia" {
  bgp_asn    = 65303
  ip_address = var.virginia_ip
  type       = "ipsec.1"

  tags = {
    Name = join("", [var.coid, "-Virginia-CGW"])
  }
}

 resource "aws_vpn_connection" "NY" {
  transit_gateway_id  = aws_ec2_transit_gateway.main_tgw.id
  customer_gateway_id = aws_customer_gateway.ny.id
  type                = "ipsec.1"
  static_routes_only  = false
  tags = {
    Name = join("", [var.coid, "-Miami-ipsec"])
  }
}

 resource "aws_vpn_connection" "Virginia" {
  transit_gateway_id  = aws_ec2_transit_gateway.main_tgw.id
  customer_gateway_id = aws_customer_gateway.virginia.id
  type                = "ipsec.1"
  static_routes_only  = false
  tags = {
    Name = join("", [var.coid, "-Miami-ipsec"])
  }
}
