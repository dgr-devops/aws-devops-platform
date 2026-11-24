variable "project" {
  description = "Nombre del proyecto, usado como prefijo de recursos."
  type        = string
  default     = "devops-platform"
}

variable "environment" {
  description = "Entorno (dev, prod...)."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "Región de AWS."
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Número de zonas de disponibilidad (una subred pública y una privada por zona)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count debe estar entre 1 y 3."
  }
}

variable "instance_type" {
  description = "Tipo de instancia. t3.micro/t2.micro entran en la capa gratuita según la antigüedad de la cuenta (ver docs/costes.md)."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI a usar. Si es null se busca la última Debian 12 oficial."
  type        = string
  default     = null
}

variable "root_volume_gb" {
  description = "Tamaño del disco raíz (GB)."
  type        = number
  default     = 20
}

variable "create_budget" {
  description = "Crea el presupuesto y las alertas de coste de AWS Budgets."
  type        = bool
  default     = true
}

variable "budget_limit_usd" {
  description = "Límite mensual del presupuesto en USD."
  type        = number
  default     = 5
}

variable "budget_alert_emails" {
  description = "Emails que reciben las alertas de presupuesto."
  type        = list(string)
  default     = []
}
