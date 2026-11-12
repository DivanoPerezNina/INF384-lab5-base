# Decisiones · Laboratorio 5

## Equipo

Número de equipo: 1

| Código PUCP | Nombre | Rol | Usuario de GitHub |
|---|---|---|---|
| | | Moderador | vitayien |
| | | Escriba | Portador3 |
| | | Abogado del diablo | RodrigoR4 |
| | | Guardián del tiempo | 31adrianpc |
| 20221481 | Divano Estefano Perez Nina | Integrador | DivanoPerezNina |

## A1 · Postmortem

### Resumen

El viernes 06/11 a las 17:55 se aplicó en producción un cambio de Terraform que dejó el bucket de comprobantes legible para cualquier persona en internet. El cambio buscaba dar lectura al proveedor de conciliación, pero la política del bucket usó `Principal = "*"` y retiró los cuatro bloqueos de acceso público. Como los nombres de los comprobantes son números correlativos, bastaba cambiar el número al final de la dirección para leer comprobantes ajenos. El bucket estuvo abierto 63 horas y 25 minutos, hasta que on-call activó el bloqueo de acceso público desde la consola el lunes 09/11 a las 09:20. El código de `infra/` no se corrigió, así que el próximo `terraform apply` vuelve a abrir el bucket.

### Impacto

- 41 300 comprobantes expuestos (origen, destino, monto y fecha de cada transferencia) durante 63 h 25 min, del 06/11 17:55 al 09/11 09:20.
- No se puede saber cuántos comprobantes se descargaron ni quién lo hizo: el bucket no tenía registros de acceso. Para efectos de notificación se trata a los 41 300 como potencialmente descargados.
- Al menos un comprobante ajeno se publicó en redes sociales el 09/11.
- El proveedor de conciliación no tiene acceso desde el 09/11 09:25. El contrato cobra una penalidad por cada día de retraso, que sigue corriendo.
- Penalidad contractual: S/ 15 000 por cada día sin acceso del proveedor, desde el 09/11 a las 09:25. Sigue corriendo (dato recibido a las 16:40 del 12/11).
- Riesgo latente: `infra/s3.tf` sigue igual que en el commit `bd600fe`. Cualquier `terraform apply` revierte el bloqueo hecho a mano en la consola.

### Línea de tiempo

| Fecha y hora | Hecho |
|---|---|
| Jue 05/11 · 15:10 | El área comercial informa que el proveedor de conciliación debe leer los comprobantes desde el 06/11, con penalidad diaria por retraso. |
| Vie 06/11 · 09:30 | La tarea se asigna a un desarrollador backend. Ninguno había modificado `infra/` antes. La ingeniera de plataforma, única persona con experiencia en Terraform, está de vacaciones hasta el 13/11. |
| Vie 06/11 · 16:20 | El desarrollador pide al proveedor el ID de su cuenta de AWS. No hay respuesta. |
| Vie 06/11 · 17:30 | Se pide revisión por chat. El líder técnico, en reunión, responde "dale, lo vemos el lunes". |
| Vie 06/11 · 17:42 | Commit `bd600fe` directo a `main` (sin branch protection). El pipeline `ci` solo corre pruebas unitarias y pasa en verde. |
| Vie 06/11 · 17:55 | `terraform apply` desde una laptop. El proveedor confirma que puede leer. **Inicio de la exposición.** |
| Sáb 07/11 y Dom 08/11 | Sin alertas: no hay monitoreo sobre la configuración del bucket. |
| Lun 09/11 · 08:15 | Un cliente publica en redes el link de un comprobante ajeno, obtenido cambiando el número final de la dirección. **Detección (externa).** |
| Lun 09/11 · 08:50 | Soporte escala a on-call por chat (35 min después de la publicación). |
| Lun 09/11 · 09:20 | On-call activa el bloqueo de acceso público desde la consola. `infra/` no se modifica. **Fin de la exposición.** |
| Lun 09/11 · 09:25 | El proveedor de conciliación pierde el acceso. |
| Lun 09/11 · 11:00 | Se buscan registros de acceso al bucket: no existen. |
| Mar 10/11 · 10:00 | Gerencia pide informe y plan de prevención. |
| Jue 12/11 · 16:40 | El proveedor exige acceso hoy (S/ 15 000 por día sin acceso) y Gerencia pide el nombre de quien hizo el cambio. El equipo responde sin nombrar a una persona (ver A3). |
| Jue 12/11 | El equipo agrega los jobs `iac` y `sca`, corrige `infra/s3.tf` y registra las excepciones (Parte B). |

### Causas

Ninguna de estas causas es "error humano". Son condiciones del sistema que permitieron que un cambio inseguro llegara a producción sin que nada lo detuviera.

**De proceso**

1. **La aprobación no exigía revisar el cambio.** Un "dale" por chat, dado desde una reunión y sin ver el diff, bastó como aprobación. `main` no tiene branch protection, así que el commit entró directo sin pull request ni revisor.
2. **Una sola persona conoce Terraform y no hay respaldo.** Con la ingeniera de plataforma de vacaciones, el cambio de infraestructura quedó a cargo de alguien que nunca había tocado `infra/`, sin nadie que pudiera revisarlo.
3. **La presión de plazo no tenía una vía de escalamiento.** La penalidad contractual empujó a entregar el viernes por la tarde. Faltaba el ID de cuenta del proveedor y no existía una ruta definida para escalar o renegociar, así que `Principal = "*"` fue la forma de cumplir el plazo.

**De pipeline**

4. **El pipeline no revisa la infraestructura ni las dependencias.** `ci.yml` solo corría `npm test`. Checkov sobre `bd600fe` reporta 6 checks nuevos en el bucket (ver Datos del repositorio) que habrían bloqueado el cambio.

**De plataforma**

5. **`terraform apply` se ejecuta a mano desde una laptop**, sin un plan revisado ni registro centralizado de quién aplicó qué. La corrección del lunes también fue manual y en consola, lo que dejó a `infra/` desalineado con producción.
6. **El bucket no tenía registros de acceso ni monitoreo de configuración.** Nadie se enteró en 63 horas; la detección vino de un cliente en redes, y hoy no se puede medir el alcance.
7. **Los comprobantes tienen nombres predecibles** (`comprobantes/AAAA-MM-DD/00000007.txt`, en `src/comprobantes.js`). Con el bucket abierto, eso permitió enumerarlos uno por uno.

### Qué funcionó y qué no funcionó

**Funcionó**
- Una vez escalado, on-call contuvo la exposición en 30 minutos (08:50 a 09:20).
- On-call tenía acceso a la consola y conocía el control correcto (bloqueo de acceso público).
- Soporte supo a quién escalar.

**No funcionó**
- La detección dependió de un cliente. No hubo ninguna alerta interna en 63 horas.
- La contención se hizo solo en consola. El código sigue abierto, y el proveedor perdió el acceso sin un plan para restituirlo.
- Sin registros de acceso no hay forma de medir el impacto ni de responder a gerencia cuántos comprobantes salieron.
- La revisión "lo vemos el lunes" llegó después de que el cambio ya estaba en producción.

### Acciones

| Acción | Rol responsable | Fecha límite |
|---|---|---|
| Agregamos los jobs `iac` (Checkov) y `sca` (Trivy) a `ci.yml` con la política de la Decisión 1. | Desarrolladores backend | 2026-11-12 |
| Corregimos `infra/s3.tf`: bloqueo de acceso público activo, política con el rol `conciliacion-lectura` de la cuenta 111122223333 y registros de acceso. | Desarrolladores backend | 2026-11-12 |
| Revisamos con una segunda persona y aplicamos hoy la corrección de `infra/s3.tf` para devolver el acceso al proveedor con su rol, sin acceso público. | Líder técnico | 2026-11-12 |
| Revisamos y aplicamos la corrección de `infra/s3.tf` para alinear producción con el código y devolver el acceso al proveedor de conciliación sin acceso público. Coordinamos con el proveedor que su rol tenga permiso `s3:GetObject` sobre el bucket. | Ingeniera de plataforma | 2026-11-16 |
| Activamos branch protection en `main`: pull request obligatorio, una aprobación y los checks `unit`, `iac` y `sca` requeridos. | Líder técnico | 2026-11-13 |
| Activamos el bloqueo de acceso público de S3 a nivel de cuenta y una regla de AWS Config (`s3-bucket-level-public-access-prohibited`) que alerta a on-call. | Ingeniera de plataforma | 2026-11-20 |
| Activamos eventos de datos de CloudTrail sobre el bucket de comprobantes, además de los registros de acceso de S3. | Ingeniera de plataforma | 2026-11-20 |
| Notificamos a los titulares de los 41 300 comprobantes y evaluamos con el área legal la comunicación a la Autoridad Nacional de Protección de Datos Personales. | Líder técnico con Gerencia | 2026-11-16 |
| Escribimos el runbook de on-call: toda contención en consola se codifica en `infra/` con un pull request el mismo día, y se avisa a los terceros afectados. | Líder técnico | 2026-11-20 |
| Definimos la ruta de escalamiento para plazos contractuales: si falta información del tercero o no hay revisor, se escala al líder técnico y al área comercial antes de cambiar `infra/`. | Líder técnico | 2026-11-20 |
| Movemos `terraform plan` al pull request y `terraform apply` a un pipeline con estado remoto. Ya no se aplica desde laptops. | Ingeniera de plataforma | 2026-11-30 |
| Cambiamos las claves de los comprobantes a identificadores no predecibles y servimos la descarga con URL prefirmadas de corta duración. | Desarrolladores backend | 2026-11-30 |
| Capacitamos a dos desarrolladores backend como revisores de Terraform para que la ingeniera de plataforma no sea la única. | Ingeniera de plataforma | 2026-12-11 |
| Migramos la Function URL a API Gateway con autorizador JWT y cerramos la excepción EXC-01. | Líder técnico | 2026-12-11 |

### Datos del repositorio

- SHA del commit que introdujo el cambio: `bd600fe3307d5aa35bb3acbff8df91e0e02fcf35` (`feat(infra): lectura de comprobantes para conciliacion`, directo a `main`, solo modifica `infra/s3.tf`).
- Fecha y hora de ese commit: 2026-11-06 17:42:00 -0500.
- Checks de Checkov que fallan sobre el bucket de comprobantes (Checkov 3.4.5, `checkov -d infra`): 12 en total.
  - Introducidos por `bd600fe` (no fallaban en el commit anterior `d1e708f`):
    - `CKV_AWS_53` block public ACLs · `aws_s3_bucket_public_access_block.comprobantes` · `infra/s3.tf:5-12`
    - `CKV_AWS_54` block public policy · `aws_s3_bucket_public_access_block.comprobantes` · `infra/s3.tf:5-12`
    - `CKV_AWS_55` ignore public ACLs · `aws_s3_bucket_public_access_block.comprobantes` · `infra/s3.tf:5-12`
    - `CKV_AWS_56` restrict public buckets · `aws_s3_bucket_public_access_block.comprobantes` · `infra/s3.tf:5-12`
    - `CKV_AWS_70` acción permitida a cualquier Principal · `aws_s3_bucket_policy.conciliacion` · `infra/s3.tf:14-27`
    - `CKV2_AWS_6` el bucket no tiene un public access block efectivo · `aws_s3_bucket.comprobantes` · `infra/s3.tf:1-3`
  - Ya fallaban antes del incidente, sobre `aws_s3_bucket.comprobantes`: `CKV_AWS_18` (registros de acceso), `CKV_AWS_21` (versionado), `CKV_AWS_144` (replicación entre regiones), `CKV_AWS_145` (cifrado KMS), `CKV2_AWS_61` (ciclo de vida), `CKV2_AWS_62` (notificaciones de eventos).

## A2 · Decisiones

### Decisión 1 · Qué bloquea y qué informa

- Decisión: bloqueamos solo los hallazgos de la misma clase que el incidente y el resto se informa en el log.
  - **Checkov bloquea 8 checks** (`hard-fail-on` en `.checkov.yaml`): `CKV_AWS_53`, `CKV_AWS_54`, `CKV_AWS_55`, `CKV_AWS_56`, `CKV2_AWS_6` y `CKV_AWS_70` (exposición pública del bucket), `CKV_AWS_18` (sin registros de acceso no se puede medir una fuga) y `CKV_AWS_258` (Function URL sin autenticación, ver Decisión 3). Los otros 20 se informan (`soft-fail: true`).
  - **Trivy bloquea severidad HIGH y CRITICAL**, tengan o no versión corregida. MEDIUM, LOW y UNKNOWN se informan.
- Dato del repositorio que la sustenta:
  - Checkov 3.4.5 sobre `infra/` del repositorio base: **28 hallazgos** (20 checks pasan, 9 recursos). En el repositorio base fallan los 8 ID bloqueantes, uno por cada ID. 6 de ellos son exactamente los que introdujo `bd600fe`.
  - Trivy sobre `package-lock.json` del repositorio base: **5 hallazgos**. Bloquean 3 (HIGH): `CVE-2021-23337` (lodash 4.17.20, inyección de comandos en `_.template`, corregida en 4.17.21), `CVE-2026-4800` (lodash 4.17.20, inyección de código en `_.template`, corregida en 4.18.0) y `CVE-2024-29415` (ip 2.0.1, SSRF, sin versión corregida). Se informan 2 (MEDIUM): `CVE-2020-28500` (lodash, ReDoS, corregida en 4.17.21) y `CVE-2025-13465` (lodash, prototype pollution en `_.unset` y `_.omit`, corregida en 4.17.23).
  - `src/comprobantes.js` usa `_.template`, la función afectada por las dos CVE HIGH de lodash.
- Alternativa descartada y por qué:
  - *Bloquear todo:* deja el pipeline en rojo por 20 checks sin relación con el incidente (KMS, VPC, X-Ray, replicación, DLQ) que requieren diseño y presupuesto. Un pipeline que siempre está en rojo enseña a ignorarlo o a saltarlo, que es justo lo que falló el 06/11.
  - *Solo informar:* es el estado que dejó pasar `bd600fe`. Un hallazgo que no detiene nada no habría evitado este incidente.
- Posición en minoría: el abogado del diablo propuso bloquear también `CKV_AWS_288`, `CKV_AWS_289`, `CKV_AWS_290` y `CKV_AWS_355` sobre `aws_iam_role_policy.api` (`infra/iam.tf:14-26`), porque `s3:*` sobre `Resource = "*"` permite que una Lambda comprometida lea o borre todos los comprobantes, que es el mismo daño del incidente por otra puerta. El equipo lo deja en informar por ahora porque corregirlo exige inventariar qué buckets y acciones usa la API, y lo agenda como siguiente paso de la Ingeniera de plataforma.

### Decisión 2 · La vulnerabilidad sin versión corregida

- Decisión: **reemplazamos la librería `ip`** por `net.BlockList`, que viene incluida en Node. Se eliminó `ip` de `package.json` y `package-lock.json`. El job `sca` mantiene `ignore-unfixed: false`, así que una vulnerabilidad HIGH o CRITICAL sin versión corregida sigue bloqueando; solo se deja pasar con una excepción con sus cuatro datos en `.trivyignore` y `EXCEPCIONES.md`.
- Dato del repositorio que la sustenta: `CVE-2024-29415` (GHSA-2p57-rm9w-gvfp), librería `ip` versión `2.0.1`, sin versión corregida. Se usa en un solo lugar: `src/notificaciones.js`, función `validarUrlNotificacion`, línea 20 (`ip.isPrivate(host)`), que protege `POST /comercios/notificacion` contra SSRF. La CVE es justo una clasificación errónea de direcciones internas como públicas: `https://[::ffff:127.0.0.1]/` llega a la función como `::ffff:7f00:1` y la validación lo deja pasar.
- Alternativa descartada y por qué:
  - *Bloquear los despliegues hasta que exista la versión corregida:* `ip` no publica versiones desde 2.0.1 (febrero de 2024). Esperar es congelar los despliegues sin fecha, incluidas las correcciones de seguridad de este mismo incidente.
  - *Abrir una excepción:* aceptaría una SSRF explotable en un endpoint donde cualquier comercio registra la URL que quiera. No hay un control compensatorio razonable, y reemplazar la librería cuesta una función.
- Posición en minoría: el abogado del diablo defendió una excepción de dos semanas: escribir a mano un control de seguridad bajo presión de tiempo puede introducir un hueco nuevo, y una librería mantenida (por ejemplo `ipaddr.js`) sería más confiable que código propio. El equipo respondió con pruebas unitarias de las variantes de la CVE en `test/notificaciones.test.js`, y deja como pendiente que la validación también revise la IP a la que resuelve un nombre de dominio, que ni `ip` ni el reemplazo cubren.

### Decisión 3 · La Function URL sin autenticación

- Decisión: **abrimos una excepción** (EXC-01 en `EXCEPCIONES.md` y `#checkov:skip=CKV_AWS_258` dentro del recurso). Responsable: Líder técnico. Vence: 2026-12-11. Control compensatorio: `reserved_concurrent_executions = 50` en la Lambda, y `CKV_AWS_258` sigue en `hard-fail-on` para cualquier otra Function URL. Riesgo aceptado: por 30 días cualquiera con la URL puede invocar la API sin identificarse.
- Dato del repositorio que la sustenta: check `CKV_AWS_258` ("Ensure that Lambda function URLs AuthType is not None"), recurso `aws_lambda_function_url.api` en `infra/lambda.tf` (`authorization_type = "NONE"`). `src/handler.js` no valida identidad en ninguna ruta.
- Alternativa descartada y por qué: *corregir ahora* (`authorization_type = "AWS_IAM"`). La app móvil consume la URL directamente y no firma con SigV4, así que el cambio deja sin servicio a todos los usuarios de la billetera. Corregirlo bien requiere poner API Gateway con autorizador JWT y publicar una nueva versión de la app, lo que no cabe en un cambio de Terraform.
- Posición en minoría: el abogado del diablo sostuvo que hay que corregir ya, porque el riesgo aceptado es mayor que el del bucket: `/transferir` no valida identidad, así que con la URL alguien puede mover dinero entre cuentas, y el límite de concurrencia no impide eso. Pidió al menos acortar el vencimiento. El equipo mantuvo la excepción por la caída total del servicio, pero se registra que el control compensatorio es débil y que el vencimiento no se extiende.

## A3 · Dato nuevo

Dato recibido (16:40): el proveedor de conciliación exige acceso hoy y cobra S/ 15 000 por cada día sin acceso. Gerencia pide el nombre de quien hizo el cambio para sancionarlo.

- Qué cambia en el postmortem:
  - Impacto: se agrega la penalidad de S/ 15 000 por día sin acceso. El proveedor está sin acceso desde el 09/11 a las 09:25, así que a hoy 12/11 van más de tres días (estimado: más de S/ 45 000; el caso no indica cómo se cuentan los días) y el costo sigue corriendo.
  - Línea de tiempo: nueva fila del 12/11 con la exigencia del proveedor y el pedido de Gerencia.
  - Causas: no se agrega una causa nueva. Refuerza la causa 3 (presión de plazo sin ruta de escalamiento) y el punto de "No funcionó": la contención del lunes cortó el acceso del proveedor sin un plan para restituirlo.
  - Acciones: se agrega una acción (ver tabla de Acciones): el Líder técnico revisa y aplica hoy el cambio de `infra/s3.tf` con una segunda persona revisora, en lugar de esperar al 16/11.
- Qué cambia en las decisiones:
  - Ninguna de las tres decisiones cambia. La Decisión 1 (qué bloquea), la 2 (CVE sin versión corregida) y la 3 (Function URL) son sobre la política del pipeline, y la penalidad y el pedido de un nombre no las afectan.
  - Dato del repositorio: el acceso del proveedor ya se restituye sin abrir el bucket al público. `infra/s3.tf` da `s3:GetObject` solo al rol `conciliacion-lectura` de la cuenta `111122223333` sobre `comprobantes/*`, y los cuatro bloqueos de acceso público quedan en `true`. Lo único que se mueve es la fecha de aplicar ese cambio.
- Respuesta del equipo al pedido recibido:
  - Sobre el acceso: no reabrimos el bucket al público ni nos saltamos el pipeline por urgencia, porque esa fue la causa del incidente. Restituimos la lectura del proveedor con su rol. El Líder técnico revisa y aplica el cambio hoy, 2026-11-12, con una segunda revisión, y coordinamos con el proveedor que su rol tenga permiso `s3:GetObject` sobre el bucket.
  - Sobre el nombre: no entregamos el nombre de una persona. El cambio llegó a producción porque el sistema lo permitió: el commit `bd600fe` entró directo a `main` sin branch protection, el pipeline solo corría pruebas unitarias y la aprobación fue un mensaje de chat. Sancionar a una persona no cambia nada de eso y haría que el próximo incidente se oculte. Entregamos a Gerencia el plan con un rol responsable y una fecha para cada acción.

## Parte B · Evidencia

| Evidencia | Link |
|---|---|
| Run fallido: el gate detiene el bucket público | |
| Run en verde en `main` después de las correcciones | |
| Pull requests del equipo | |

## Declaración de uso de IA

Herramientas usadas y para qué se usó cada una:
