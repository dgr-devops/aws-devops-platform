#!/usr/bin/env bash
# Prueba apply + destroy SOLO contra LocalStack (nunca AWS real). Requiere Docker y Terraform.
# Uso: scripts/localstack-test.sh [bootstrap|main]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACK="${1:-main}"
DIR="$ROOT/terraform"; [ "$STACK" = bootstrap ] && DIR="$ROOT/terraform/bootstrap"
ARGS=()
if [ "$STACK" = main ]; then
  # AWS Budgets no está en LocalStack Community; AMI de prueba propia de LocalStack (no existen las de Debian).
  ARGS=(-var create_budget=false -var ami_id=ami-03cf127a)
fi
docker inspect localstack >/dev/null 2>&1 || docker run -d --name localstack -p 127.0.0.1:4566:4566 localstack/localstack:3.8 >/dev/null
until curl -sf http://127.0.0.1:4566/_localstack/health >/dev/null; do sleep 2; done
cd "$DIR"
cp "$ROOT/terraform/localstack.tf.example" localstack_override.tf
# Estado local de usar y tirar (el backend s3 real no se toca).
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
cleanup() { rm -f localstack_override.tf backend_override.tf terraform.tfstate terraform.tfstate.backup; }
trap cleanup EXIT
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test
terraform init -reconfigure -input=false >/dev/null
terraform apply -auto-approve -no-color -input=false "${ARGS[@]}"
terraform destroy -auto-approve -no-color -input=false "${ARGS[@]}"
