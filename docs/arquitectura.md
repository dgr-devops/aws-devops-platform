# Arquitectura

> Diseño objetivo. **Nunca se ha desplegado en AWS real**; las pruebas se hicieron con LocalStack (ver README).

```mermaid
flowchart LR
  dev([Desarrollador]) -->|push / PR| gh[GitHub Actions]
  gh -->|build + Trivy| ghcr[(GHCR<br/>imagen)]
  gh -.->|deploy.yml manual<br/>OIDC, NO ejecutado| aws

  subgraph aws[AWS · eu-west-1]
    subgraph vpc[VPC 10.20.0.0/16]
      subgraph pub[Subred pública]
        ec2[EC2 Debian 12<br/>Docker: API + Postgres<br/>IMDSv2, EBS cifrado]
      end
      subgraph priv[Subredes privadas]
        reserved[Reservadas<br/>p. ej. RDS]
      end
      igw[Internet Gateway]
    end
    ssm[SSM Session Manager]
    s3[(S3 estado remoto<br/>versionado + cifrado)]
    ddb[(DynamoDB lock)]
    bud[AWS Budgets<br/>alertas de coste]
    cwl[CloudWatch Logs<br/>VPC Flow Logs REJECT]
  end

  ghcr -->|docker pull 443| ec2
  ec2 --- igw
  op([Operador]) -->|túnel SSM, sin SSH abierto| ssm --> ec2
  tf[Terraform] --> s3
  tf --> ddb
  bud -->|email| op

  subgraph mon[Monitorización · docker compose]
    prom[Prometheus] --> am[Alertmanager] --> wh[Webhook]
    prom --> graf[Grafana]
  end
  prom -.->|scrape /metrics| ec2
```

## Componentes

| Capa | Pieza | Directorio |
|---|---|---|
| Aplicación | FastAPI + SQLAlchemy + Alembic + Postgres, `/health`, `/metrics` | `app/` |
| Imagen | Multi-stage, usuario no root (UID 10001), `HEALTHCHECK` | `app/Dockerfile` |
| CI/CD | Lint, tests, Trivy, promtool, Ansible en contenedor, build + push a GHCR | `.github/workflows/` |
| Infraestructura | VPC, subredes, SG sin entrada, EC2 + SSM, flow logs, Budgets | `terraform/` |
| Estado remoto | S3 + DynamoDB (stack aparte) | `terraform/bootstrap/` |
| Configuración | Bastionado, Docker, despliegue | `ansible/` |
| Observabilidad | Prometheus, Alertmanager, Grafana, 2 alertas con tests | `monitoring/` |
