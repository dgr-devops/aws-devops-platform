# Sin reglas de entrada: ni SSH ni HTTP desde Internet. El acceso es por SSM Session Manager
# (shell y port-forward a la API). Ver docs/decisiones.md.
resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "Instancia de la aplicacion: sin entrada, salida solo 80/443"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-app" }
}

# Salida HTTPS: SSM, GHCR, repositorios de paquetes.
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS saliente (SSM, GHCR, APT)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  #trivy:ignore:AVD-AWS-0104
  cidr_ipv4 = "0.0.0.0/0"
}

# Salida HTTP: repositorios APT de Debian (deb.debian.org sirve por HTTP).
resource "aws_vpc_security_group_egress_rule" "http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP saliente (APT)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  #trivy:ignore:AVD-AWS-0104
  cidr_ipv4 = "0.0.0.0/0"
}

# DNS dentro de la VPC (resolver de Amazon en la base del CIDR + 2).
resource "aws_vpc_security_group_egress_rule" "dns_udp" {
  security_group_id = aws_security_group.app.id
  description       = "DNS UDP al resolver de la VPC"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = var.vpc_cidr
}
