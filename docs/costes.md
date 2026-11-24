# Costes (estimación)

> Estimación, **no medición**: nunca se ha desplegado nada en AWS. Las cifras de precio no se han verificado contra la calculadora
> de AWS salvo donde se indica.

## Verificado en la web de AWS (https://aws.amazon.com/free/, consultada el 2026-11-24)
- El plan gratuito para cuentas nuevas da **hasta 200 USD en créditos durante 6 meses** (100 al crear la cuenta + hasta 100 por
  explorar servicios); la cuenta se cierra a los 6 meses o al agotar los créditos si no se pasa a plan de pago.
- Instancias EC2 elegibles en el plan gratuito: **T3.micro**, T3.small, T4g.micro, T4g.small, C7i-flex.large, M7i-flex.large.
  Por eso el valor por defecto es `t3.micro`.
- No he comprobado los límites del modelo anterior (750 h/mes durante 12 meses para cuentas antiguas): **sin verificar**.

## Recursos que crea este proyecto y su coste esperado
| Recurso | Notas | Coste (sin verificar) |
|---|---|---|
| EC2 `t3.micro` | Cubierto por créditos en plan gratuito | ~0 con créditos; unos 8–10 USD/mes de pago si 24x7 |
| EBS gp3 20 GB cifrado | | pocos USD/mes |
| IP pública | AWS cobra por IPv4 pública | pocos USD/mes |
| VPC, subredes, IGW, SG | | 0 |
| NAT Gateway | **No se crea** a propósito | evita ~30+ USD/mes |
| S3 estado + DynamoDB (on-demand) | Uso mínimo | ~0 |
| VPC Flow Logs (REJECT, 14 días) | Volumen bajo | céntimos |
| AWS Budgets | Los primeros presupuestos con alertas son gratuitos | 0 (confirmar) |

## Protecciones
- `aws_budgets_budget` mensual de 5 USD por defecto (`budget_limit_usd`) con avisos al 50 % y 80 % real y 100 % previsto.
- Los avisos de Budgets **no detienen** el gasto: son alertas. Destruye el entorno al terminar (`destruir.md`).
