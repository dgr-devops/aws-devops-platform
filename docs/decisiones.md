# Decisiones de diseño

Formato: contexto → decisión → alternativa descartada.

## 1. Sin SSH ni HTTP abiertos: acceso por SSM
El security group de la instancia **no tiene reglas de entrada**. La shell y el acceso a la API (puerto 8000) van por túnel
de AWS Systems Manager (`AWS-StartSSHSession` / `AWS-StartPortForwardingSession`), autenticado con IAM.
*Descartado:* abrir el 22 a mi IP (cambia con frecuencia, y una regla olvidada es un riesgo) y un bastión (coste y más superficie).
Consecuencia: la API no es pública. Para exponerla habría que añadir un ALB (coste adicional, fuera del presupuesto).

## 2. Sin NAT Gateway
Un NAT Gateway cuesta 0,045 USD/h (≈ 33 USD/mes) más 0,045 USD/GB procesado, según la página de precios de VPC. La instancia va en subred
pública con IP pública **solo para salida**; la entrada sigue cerrada. Las subredes privadas existen (sin ruta a Internet) para una
futura RDS. Los hallazgos de Trivy `AVD-AWS-0164` (IP pública) y `AVD-AWS-0104` (egress 0.0.0.0/0) están suprimidos con comentario
`#trivy:ignore` en el código por este motivo; el egress se limita a 80/443 y DNS de la VPC.

## 3. Estado remoto en un stack aparte (bootstrap)
El bucket S3 y la tabla DynamoDB no pueden guardar su propio estado antes de existir. `terraform/bootstrap` se aplica una vez con
estado local; el stack principal declara `backend "s3" {}` vacío y recibe los valores con `-backend-config` (ver `backend.hcl.example`).
Así no hay nombres de cuenta en el repositorio y el mismo código sirve para cualquier cuenta.
*Descartado:* `use_lockfile` de S3 (solo en Terraform ≥ 1.10) para mantener compatibilidad con ≥ 1.6 y el patrón clásico DynamoDB.

## 4. LocalStack como override, nunca por defecto
Los endpoints de LocalStack viven en `terraform/localstack.tf.example`; se copian a `localstack_override.tf` solo durante la prueba
(`scripts/localstack-test.sh`). El código principal apunta siempre a AWS real y ese fichero está fuera del flujo normal.

## 5. Cifrado y trazabilidad al coste justo
S3 de estado: versionado, SSE-S3 (AES256), bloqueo de acceso público. No se usa KMS propio (1 USD/mes por clave) ni logs de acceso
del bucket (`AVD-AWS-0132`, `AVD-AWS-0089` suprimidos con comentario). VPC Flow Logs solo `REJECT` y retención de 14 días.

## 6. Debian 12 en la instancia
Coherente con el rol de bastionado y las pruebas de Ansible (contenedor Debian 12). Si la AMI no trae el agente SSM, `user_data`
lo instala desde el bucket regional oficial de AWS. *Esto último no se ha podido probar sin una instancia real.*

## 7. Despliegue de la app con Ansible + compose
Un único servidor no justifica orquestador. El rol `app` genera un `docker-compose.yml` y un `.env` (0600) con la contraseña de la
base de datos, que debe pasarse con `ansible-vault`; el rol falla si falta.

## 8. CI reutiliza workflows compartidos
Lint, tests, build+Trivy y Terraform vienen de `dgr-devops/github-actions-reusable-workflows@v1`. Los jobs específicos de este
repositorio (Trivy config, promtool, Ansible) son locales.

## 9. `deploy.yml` es una plantilla
Asume un rol por OIDC (sin claves), exige escribir `DESPLEGAR` y usa un *environment* protegido. No se ha ejecutado nunca.
