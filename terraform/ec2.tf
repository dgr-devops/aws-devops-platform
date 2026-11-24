data "aws_ami" "debian" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["136693071363"] # Debian (cuenta oficial de publicación de AMIs)

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami                    = coalesce(var.ami_id, one(data.aws_ami.debian[*].id))
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  # Instala el agente SSM si la AMI no lo trae (procedimiento documentado por AWS para Debian).
  user_data = <<-EOT
    #!/bin/bash
    set -eu
    if ! systemctl list-unit-files | grep -q amazon-ssm-agent; then
      curl -fsSL -o /tmp/ssm.deb "https://s3.${var.region}.amazonaws.com/amazon-ssm-${var.region}/latest/debian_amd64/amazon-ssm-agent.deb"
      dpkg -i /tmp/ssm.deb
    fi
    systemctl enable --now amazon-ssm-agent
  EOT

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 obligatorio
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
    encrypted   = true
  }

  monitoring = false # monitorización detallada de pago; usamos Prometheus

  tags = { Name = "${local.name}-app" }

  lifecycle {
    ignore_changes = [ami] # evita reemplazar la instancia cuando sale una AMI nueva
  }
}
