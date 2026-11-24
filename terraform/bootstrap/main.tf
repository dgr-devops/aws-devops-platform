# Stack de bootstrap: crea el bucket S3 y la tabla DynamoDB del estado remoto.
# Se aplica UNA vez con estado local; después terraform/ usa estos recursos como backend.
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

variable "region" {
  description = "Región de AWS."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Prefijo de los recursos."
  type        = string
  default     = "devops-platform"
}

variable "force_destroy" {
  description = "Permite destruir el bucket aunque contenga objetos y versiones (solo para teardown; ver docs/destruir.md)."
  type        = bool
  default     = false
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
}

# Sin log de acceso ni KMS propio: se documenta como decisión de coste en docs/decisiones.md.
#trivy:ignore:AVD-AWS-0089
resource "aws_s3_bucket" "state" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  lifecycle {
    prevent_destroy = false # true en un entorno real; false para poder probar la destrucción (docs/destruir.md)
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Tabla de bloqueo. Pago por petición: coste ~0 con uso esporádico.
resource "aws_dynamodb_table" "lock" {
  name         = "${var.project}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  #trivy:ignore:AVD-AWS-0025
  server_side_encryption {
    enabled = true
  }
}

output "state_bucket" {
  description = "Bucket del estado remoto."
  value       = aws_s3_bucket.state.id
}

output "lock_table" {
  description = "Tabla DynamoDB de bloqueo."
  value       = aws_dynamodb_table.lock.name
}
