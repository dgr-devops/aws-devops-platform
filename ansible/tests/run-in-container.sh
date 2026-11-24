#!/usr/bin/env bash
# Prueba el playbook en un contenedor Debian 12 desechable: 1ª pasada aplica, 2ª debe dar changed=0.
# Sin START_APP no arranca servicios; no hay systemd en el contenedor (ver README).
set -euo pipefail
cd "$(dirname "$0")/.."
NAME=ansible-test
docker rm -f "$NAME" >/dev/null 2>&1 || true
# START_APP=1: monta el socket del Docker del host para probar de verdad `docker compose up`
# (los contenedores de la app se crean en el host y se eliminan al final).
EXTRA=(); START=false
if [ "${START_APP:-0}" = 1 ]; then EXTRA=(-v /var/run/docker.sock:/var/run/docker.sock); START=true; fi
docker run -d --name "$NAME" -v "$PWD":/ansible:ro "${EXTRA[@]}" debian:12 sleep 3600 >/dev/null
cleanup() {
  [ "$START" = true ] && docker exec "$NAME" docker compose -f /opt/devops-platform/docker-compose.yml down -v >/dev/null 2>&1 || true
  docker rm -f "$NAME" >/dev/null
}
trap cleanup EXIT
docker exec "$NAME" bash -c 'apt-get update -qq && apt-get install -y -qq python3-venv >/dev/null && python3 -m venv /venv && /venv/bin/pip install -q ansible-core && /venv/bin/ansible-galaxy collection install community.docker >/dev/null'
run() {
  docker exec -w /ansible "$NAME" env ANSIBLE_CONFIG=/ansible/ansible.cfg ANSIBLE_ROLES_PATH=/ansible/roles \
    /venv/bin/ansible-playbook -i localhost, -c local site.yml \
    -e app_db_password=contenedor-de-pruebas-123 -e app_start=$START -e ansible_python_interpreter=/usr/bin/python3 "$@"
}
echo "=== Pasada 1 ==="; run | tee /tmp/ansible-run1.txt | tail -6
echo "=== Pasada 2 (idempotencia) ==="; run | tee /tmp/ansible-run2.txt | tail -6
grep -E 'changed=0 .*failed=0' /tmp/ansible-run2.txt >/dev/null && echo "IDEMPOTENTE: changed=0" || { echo "NO idempotente"; exit 1; }
if [ "$START" = true ]; then
  echo "=== Aplicación levantada por Ansible ==="
  for _ in $(seq 1 30); do curl -sf http://127.0.0.1:8000/health && break; sleep 3; done
  echo; docker exec "$NAME" docker compose -f /opt/devops-platform/docker-compose.yml ps --format '{{.Service}} {{.Status}}'
fi
echo "=== Comprobaciones ==="
docker exec "$NAME" bash -c 'docker --version; docker compose version; grep -c . /etc/sysctl.d/99-hardening.conf; cat /etc/ssh/sshd_config.d/10-hardening.conf | head -3; stat -c "%a %n" /opt/devops-platform/.env'
