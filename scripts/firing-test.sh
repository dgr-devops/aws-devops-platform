#!/usr/bin/env bash
# Prueba real de alertas: levanta el stack con monitorización, provoca ApiHigh5xxRate
# (parando Postgres y generando tráfico a /health => 503) y ApiDown (parando la API),
# y espera a ver ambas notificaciones en el receptor de webhooks.
set -euo pipefail
cd "$(dirname "$0")/.."
dc() { docker compose --profile monitoring "$@"; }
wait_log() { # patrón, timeout en s
  local end=$((SECONDS + $2))
  while ((SECONDS < end)); do
    dc logs webhook 2>/dev/null | grep -q "$1" && { dc logs webhook | grep "$1" | head -1; return 0; }
    sleep 5
  done
  echo "TIMEOUT esperando: $1" >&2; return 1
}
dc up -d --build
sleep 20
echo ">> Provocando 5xx: parando db y generando tráfico"
dc stop db
for _ in $(seq 1 360); do curl -s -o /dev/null http://127.0.0.1:8000/health || true; sleep 0.5; done &
LOAD=$!
wait_log 'status=firing alertname=ApiHigh5xxRate' 300
kill "$LOAD" 2>/dev/null || true
echo ">> Provocando caída: parando api"
dc stop api
wait_log 'status=firing alertname=ApiDown' 200
echo ">> OK: ambas alertas llegaron al receptor"
