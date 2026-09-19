resource "aws_vpc" "main" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.project }
}
resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id }
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.project}-public-${count.index}" }
}
resource "aws_subnet" "data" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.project}-isolated-${count.index}" }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
resource "aws_route_table" "data" { vpc_id = aws_vpc.main.id }
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "data" {
  count          = 2
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}
resource "aws_security_group" "alb" {
  name_prefix = "${var.project}-alb-"
  description = "Workstation to load balancer only"
  vpc_id      = aws_vpc.main.id
}
resource "aws_security_group" "app" {
  name_prefix = "${var.project}-app-"
  description = "Load balancer to WordPress only"
  vpc_id      = aws_vpc.main.id
}
resource "aws_security_group" "db" {
  name_prefix = "${var.project}-db-"
  description = "WordPress to database only"
  vpc_id      = aws_vpc.main.id
}
resource "aws_security_group" "efs" {
  name_prefix = "${var.project}-efs-"
  description = "WordPress to shared filesystem only"
  vpc_id      = aws_vpc.main.id
}
resource "aws_vpc_security_group_ingress_rule" "web" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = local.business ? "0.0.0.0/0" : var.allowed_ipv4_cidr
  from_port         = var.certificate_arn == "" ? 80 : 443
  to_port           = var.certificate_arn == "" ? 80 : 443
  ip_protocol       = "tcp"
  description       = "Single workstation ingress"
}
resource "aws_vpc_security_group_egress_rule" "alb_app" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "db" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "efs" {
  security_group_id            = aws_security_group.efs.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "app_db" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "app_efs" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.efs.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Image pulls, AWS APIs, and HTTPS updates; lab has no NAT or interface endpoints"
}

resource "aws_subnet" "app" {
  count                   = local.private_compute ? 2 : 0
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 20)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.project}-private-app-${count.index}" }
}
resource "aws_eip" "nat" {
  count      = local.private_compute ? 2 : 0
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
}
resource "aws_nat_gateway" "main" {
  count         = local.private_compute ? 2 : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
}
resource "aws_route_table" "app" {
  count  = local.private_compute ? 2 : 0
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
}
resource "aws_route_table_association" "app" {
  count          = local.private_compute ? 2 : 0
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}
