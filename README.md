# aws-devops-platform

Plataforma DevOps de extremo a extremo para una API pequeña: **aplicación → imagen → CI/CD → infraestructura como código →
configuración con Ansible → monitorización con alertas**. Está pensada para AWS (capa gratuita) y se ha probado todo lo que se
puede probar **sin gastar dinero**.

> ⚠️ **Aviso de honestidad:** nada de este repositorio se ha aplicado jamás sobre una cuenta real de AWS. Terraform se ha
> verificado con `fmt`, `validate`, `tflint`, Trivy y `apply`/`destroy` contra **LocalStack**. El workflow `deploy.yml` **no se ha
> ejecutado**. Detalle en [Qué se ha verificado y qué no](#qué-se-ha-verificado-y-qué-no).

## Contenido

| Directorio | Qué hay |
|---|---|
| [`app/`](app) | API FastAPI (CRUD de tareas, `/health`, `/metrics`), SQLAlchemy + Alembic sobre Postgres, tests con pytest (≥ 80 %) y ruff. `Dockerfile` multi-stage, usuario no root |
| [`docker-compose.yml`](docker-compose.yml) | Entorno local: API + Postgres; perfil `monitoring` añade Prometheus, Alertmanager, Grafana y un receptor de webhooks |
| [`.github/workflows/`](.github/workflows) | `ci.yml` (lint, tests, Terraform, Trivy, promtool, Ansible, build + push a GHCR) y `deploy.yml` (plantilla manual, OIDC, **no ejecutada**) |
| [`terraform/`](terraform) | VPC con subredes públicas/privadas, SG sin entrada, EC2 con SSM, flow logs, `aws_budgets_budget`, outputs. [`bootstrap/`](terraform/bootstrap): S3 + DynamoDB para el estado remoto |
| [`ansible/`](ansible) | Roles `hardening`, `docker` y `app`; prueba idempotente en contenedor Debian 12 |
| [`monitoring/`](monitoring) | Prometheus + Alertmanager + Grafana adaptados de [monitoring-as-code](https://github.com/dgr-devops/monitoring-as-code), con 2 alertas y sus tests |
| [`docs/`](docs) | [Arquitectura](docs/arquitectura.md), [decisiones](docs/decisiones.md), [costes](docs/costes.md), [destrucción](docs/destruir.md), [evidencias](docs/evidencias) |

## Arquitectura

Diagrama completo en [docs/arquitectura.md](docs/arquitectura.md). Resumen: una EC2 Debian en una VPC propia, sin puertos
abiertos a Internet (acceso por **SSM Session Manager**), con Docker ejecutando la API y Postgres; estado de Terraform en S3 con
bloqueo en DynamoDB; alertas de coste con AWS Budgets; Prometheus/Alertmanager/Grafana para observabilidad.

## Uso rápido (local, sin AWS)

```bash
docker compose up -d --build          # API en http://127.0.0.1:8000 (docs en /docs)
curl -XPOST localhost:8000/tasks -H 'content-type: application/json' -d '{"title":"hola"}'
curl localhost:8000/health && curl localhost:8000/metrics | head
docker compose --profile monitoring up -d   # Prometheus :9090, Alertmanager :9093, Grafana :3000
```

Tests y lint de la app:

```bash
cd app && python -m venv .venv && . .venv/bin/activate
pip install -e '.[dev]'
ruff check . && ruff format --check . && pytest
```

Pruebas de infraestructura (necesitan Docker; **no tocan AWS**):

```bash
scripts/localstack-test.sh bootstrap && scripts/localstack-test.sh main   # apply + destroy en LocalStack
ansible/tests/run-in-container.sh                                          # playbook en Debian 12, 2 pasadas (START_APP=1 despliega la app de verdad)
scripts/firing-test.sh                                                     # alertas reales disparándose
docker run --rm -v "$PWD/monitoring/prometheus:/p" --entrypoint promtool prom/prometheus:v2.55.1 test rules /p/tests/api_test.yml
```

## Alertas

| Alerta | Condición | Severidad |
|---|---|---|
| `ApiDown` | `up{job="api"} == 0` durante 1 min | critical |
| `ApiHigh5xxRate` | > 5 % de respuestas 5xx (con > 0,1 req/s) durante 2 min | warning |

## Qué se ha verificado y qué no

Entorno de pruebas: Linux local con Docker. **Ninguna prueba usó una cuenta de AWS.**

| Pieza | Verificado | Cómo / resultado |
|---|---|---|
| Tests de la API | ✅ | `pytest`: 6 tests, 98 % de cobertura (umbral 80 %) |
| Lint Python | ✅ | `ruff check` y `ruff format --check` limpios |
| Migraciones | ✅ | `alembic upgrade head` contra un Postgres 16 real en Docker |
| Imagen y compose | ✅ | Build multi-stage, ejecuta como UID 10001, `healthcheck` en `healthy`, CRUD y `/metrics` contra Postgres |
| Reglas de alertas | ✅ | `promtool check rules` y `promtool test rules`: SUCCESS |
| Alertas disparándose | ✅ | [`firing-test.txt`](docs/evidencias/firing-test.txt): `ApiHigh5xxRate` (parando Postgres) y `ApiDown` (parando la API) llegan al webhook vía Alertmanager |
| Terraform estático | ✅ | `fmt -check`, `validate` (principal y bootstrap), `tflint` y `trivy config`: sin hallazgos (algunos suprimidos con motivo, ver [decisiones](docs/decisiones.md)) |
| Terraform apply/destroy | ⚠️ solo LocalStack | Bootstrap: 5 creados / 5 destruidos. Principal: 25 / 25 ([evidencias](docs/evidencias)). LocalStack Community no soporta Budgets (se prueba con `create_budget=false`) ni valida IAM/SG como AWS |
| Ansible | ✅ en contenedor | Debian 12: 1ª pasada `changed=11`, 2ª `changed=0` ([evidencia](docs/evidencias/ansible-idempotencia.txt)). Con `START_APP=1` el rol `app` despliega de verdad la imagen publicada en GHCR (pull anónimo, `/health` OK, 2ª pasada `changed=0`). Sin systemd: no se probó habilitar/arrancar servicios (`sshd`, `docker`) |
| Imagen en GHCR | ✅ | `docker pull ghcr.io/dgr-devops/aws-devops-platform:latest` funciona sin credenciales (paquete público) |
| Costes | ⚠️ parcial | Capa gratuita y tipos de instancia leídos en aws.amazon.com/free; NAT Gateway, IPv4 pública y gratuidad de Budgets leídos en las páginas de precios de AWS; el precio de EC2/EBS **no está verificado** ([costes](docs/costes.md)) |
| CI en GitHub | ✅ | Los 8 jobs en verde en runners reales: ruff, pytest, terraform (×2), Trivy config, promtool, Ansible en contenedor y build + Trivy + push a GHCR en `main` |
| `deploy.yml` | ❌ **no ejecutado** | Plantilla con OIDC; nunca lanzada, requiere un rol IAM que no existe |
| `terraform apply` en AWS real | ❌ | No realizado (sin gasto en la nube) |
| Instancia real, agente SSM, túnel SSM, AMI Debian | ❌ | Requieren una instancia real |
| Destruir el bucket de estado versionado | ✅ solo LocalStack | `BucketNotEmpty` reproducido y resuelto con `force_destroy` ([evidencia](docs/evidencias/localstack-bucket-no-vacio.txt)); en AWS real, sin verificar |

## Seguridad

- Sin claves en el repositorio: contraseñas por variable de entorno/`ansible-vault`, AWS solo por OIDC.
- Valores por defecto de `docker-compose.yml` marcados `dev-only-change-me`: solo para desarrollo local, puertos en loopback.
- Instancia: IMDSv2 obligatorio, EBS cifrado, SG sin entrada, acceso por SSM.

## Licencia

[MIT](LICENSE) © 2026 Daniel García Rodríguez
