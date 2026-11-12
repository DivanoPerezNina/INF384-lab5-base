# Excepciones vigentes

Cada excepción lleva cuatro datos: responsable (rol), fecha de vencimiento, control compensatorio y riesgo aceptado. Al vencer, el check vuelve a bloquear: se quita el `#checkov:skip` o la línea de `.trivyignore` y el pipeline se pone en rojo si no se corrigió.

| ID | Herramienta y check | Recurso | Archivo |
|---|---|---|---|
| EXC-01 | Checkov `CKV_AWS_258` | `aws_lambda_function_url.api` | `infra/lambda.tf` |
| EXC-02 | Checkov `CKV_AWS_18` | `aws_s3_bucket.registros_acceso` | `infra/s3.tf` |

## EXC-01 · Function URL sin autenticación (Decisión 3)

- **Hallazgo:** `CKV_AWS_258` "Ensure that Lambda function URLs AuthType is not None", sobre `aws_lambda_function_url.api` (`authorization_type = "NONE"`).
- **Responsable:** Líder técnico.
- **Fecha de vencimiento:** 2026-12-11.
- **Control compensatorio:** `reserved_concurrent_executions = 50` en `aws_lambda_function.api`, que acota el costo y el impacto de un abuso de la URL. El check sigue en la lista `hard-fail-on` de `.checkov.yaml`: cualquier otra Function URL sin autenticación bloquea el pipeline.
- **Riesgo aceptado:** durante 30 días cualquiera que conozca la URL puede invocar la API sin identificarse, incluidas las rutas `/saldo`, `/historial` y `/transferir`. El equipo lo acepta porque cambiar a `AWS_IAM` hoy deja sin servicio a toda la app móvil, que no firma sus llamadas con SigV4.
- **Plan de salida:** poner un API Gateway HTTP API con autorizador JWT del servicio de autenticación delante de la Lambda, publicar la versión de la app que lo consume y cambiar la Function URL a `AWS_IAM` o eliminarla.

## EXC-02 · Bucket de registros de acceso sin registros propios

- **Hallazgo:** `CKV_AWS_18` "Ensure the S3 bucket has access logging enabled", sobre `aws_s3_bucket.registros_acceso`.
- **Responsable:** Ingeniera de plataforma.
- **Fecha de vencimiento:** 2027-05-12 (revisión semestral).
- **Control compensatorio:** el bucket tiene los cuatro bloqueos de acceso público activos y su política solo permite escribir al servicio `logging.s3.amazonaws.com` desde el bucket de comprobantes de la misma cuenta.
- **Riesgo aceptado:** las lecturas de los propios registros de acceso no quedan registradas. Un bucket destino de registros no puede registrarse a sí mismo sin crear un bucle; la alternativa es un tercer bucket que tendría el mismo hallazgo.
