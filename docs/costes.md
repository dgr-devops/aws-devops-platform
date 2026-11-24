# Costes (estimación)

> Estimación, **no medición**: nunca se ha desplegado nada en AWS. Solo están verificadas las cifras de la sección siguiente;
> el resto se marca como sin verificar.

## Verificado en la web de AWS (https://aws.amazon.com/free/, consultada el 2026-11-24)
- El plan gratuito para cuentas nuevas da **hasta 200 USD en créditos durante 6 meses** (100 al crear la cuenta + hasta 100 por
  explorar servicios); la cuenta se cierra a los 6 meses o al agotar los créditos si no se pasa a plan de pago.
- Instancias EC2 elegibles en el plan gratuito: **T3.micro**, T3.small, T4g.micro, T4g.small, C7i-flex.large, M7i-flex.large.
  Por eso el valor por defecto es `t3.micro`.
- **Precios** (páginas aws.amazon.com/vpc/pricing y /aws-budgets/pricing, 2026-11-24): NAT Gateway 0,045 USD/h (≈ 33 USD/mes, más 0,045 USD/GB; la tarifa depende de la región, la de la página es un ejemplo); IPv4 pública en uso 0,005 USD/h (≈ 3,65 USD/mes); monitorizar presupuestos y recibir notificaciones es gratis (solo las *acciones* de presupuesto cobran a partir de las dos primeras).
- No he comprobado los límites del modelo anterior (750 h/mes durante 12 meses para cuentas antiguas): **sin verificar**.

## Recursos que crea este proyecto y su coste esperado
| Recurso | Notas | Coste (sin verificar) |
|---|---|---|
| EC2 `t3.micro` | Cubierto por créditos en plan gratuito | ~0 con créditos; precio de pago sin verificar |
| EBS gp3 20 GB cifrado | | pocos USD/mes |
| IP pública | 0,005 USD/h verificado | ≈ 3,65 USD/mes (el plan gratuito/créditos puede cubrirlo: sin verificar) |
| VPC, subredes, IGW, SG | | 0 |
| NAT Gateway | **No se crea** a propósito | evita ≈ 33 USD/mes (verificado: 0,045 USD/h) |
| S3 estado + DynamoDB (on-demand) | Uso mínimo | ~0 |
| VPC Flow Logs (REJECT, 14 días) | Volumen bajo | céntimos |
| AWS Budgets | Monitorización y notificaciones gratuitas (verificado) | 0 |

## Protecciones
- `aws_budgets_budget` mensual de 5 USD por defecto (`budget_limit_usd`) con avisos al 50 % y 80 % real y 100 % previsto.
- Los avisos de Budgets **no detienen** el gasto: son alertas. Destruye el entorno al terminar (`destruir.md`).
