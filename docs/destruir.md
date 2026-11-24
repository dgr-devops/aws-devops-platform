# Destrucción documentada

Orden inverso al de creación. **Comprueba siempre la cuenta y la región antes de destruir** (`aws sts get-caller-identity`).

## 1. Stack principal
```bash
cd terraform
terraform init -backend-config=backend.hcl
terraform plan -destroy        # revisa qué se va a borrar
terraform destroy
```
Recursos que desaparecen: instancia, perfil y rol IAM, flow logs y su log group, rutas, subredes, IGW, SG y VPC (25 recursos con
`create_budget=false`; el presupuesto se añade si está activo).

## 2. Stack de bootstrap (estado remoto) — al final
Solo cuando ya no queda ningún stack que use el estado. El bucket está versionado: antes de destruirlo hay que vaciar todas las
versiones, o `terraform destroy` fallará con `BucketNotEmpty`.
```bash
cd terraform/bootstrap
terraform destroy
```

## 3. Comprobación manual posterior
Revisa en la consola: EC2 (instancias y volúmenes), VPC, IP elásticas, CloudWatch Logs, S3, DynamoDB y Billing/Budgets.

## Prueba realizada
La destrucción se ha probado **solo contra LocalStack** (no contra AWS):
```bash
scripts/localstack-test.sh bootstrap   # 5 creados, 5 destruidos
scripts/localstack-test.sh main        # 25 creados, 25 destruidos
```
Salida registrada en `docs/evidencias/`. LocalStack no reproduce el comportamiento de `BucketNotEmpty` con versiones reales,
así que ese punto de la sección 2 **no está verificado**.
