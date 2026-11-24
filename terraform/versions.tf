terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Backend remoto parcial: se rellena con `terraform init -backend-config=backend.hcl`
  # (ver backend.hcl.example y docs/decisiones.md). Para pruebas locales: `init -backend=false`.
  backend "s3" {}
}
