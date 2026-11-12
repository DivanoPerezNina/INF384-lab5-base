# Excepciones vigentes

Cada excepción lleva cuatro datos: responsable (rol), fecha de vencimiento, control compensatorio y riesgo aceptado. Al vencer, el check vuelve a bloquear: se quita el `#checkov:skip` o la línea de `.trivyignore` y el pipeline se pone en rojo si no se corrigió.

| ID | Herramienta y check | Recurso | Archivo |
|---|---|---|---|
| EXC-02 | Checkov `CKV_AWS_18` | `aws_s3_bucket.registros_acceso` | `infra/s3.tf` |

## EXC-02 · Bucket de registros de acceso sin registros propios

- **Hallazgo:** `CKV_AWS_18` "Ensure the S3 bucket has access logging enabled", sobre `aws_s3_bucket.registros_acceso`.
- **Responsable:** Ingeniera de plataforma.
- **Fecha de vencimiento:** 2027-05-12 (revisión semestral).
- **Control compensatorio:** el bucket tiene los cuatro bloqueos de acceso público activos y su política solo permite escribir al servicio `logging.s3.amazonaws.com` desde el bucket de comprobantes de la misma cuenta.
- **Riesgo aceptado:** las lecturas de los propios registros de acceso no quedan registradas. Un bucket destino de registros no puede registrarse a sí mismo sin crear un bucle; la alternativa es un tercer bucket que tendría el mismo hallazgo.
