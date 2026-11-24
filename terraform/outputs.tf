output "vpc_id" {
  description = "ID de la VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas."
  value       = aws_subnet.private[*].id
}

output "instance_id" {
  description = "ID de la instancia (usar con aws ssm start-session --target)."
  value       = aws_instance.app.id
}

output "ssm_session_command" {
  description = "Comando para abrir una shell en la instancia sin SSH."
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.region}"
}

output "ssm_port_forward_command" {
  description = "Comando para acceder a la API en http://localhost:8000 por túnel SSM."
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.region} --document-name AWS-StartPortForwardingSession --parameters portNumber=8000,localPortNumber=8000"
}

output "budget_name" {
  description = "Nombre del presupuesto mensual (null si create_budget = false)."
  value       = one(aws_budgets_budget.monthly[*].name)
}
