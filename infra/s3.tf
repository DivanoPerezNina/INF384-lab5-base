data "aws_caller_identity" "actual" {}

# ---------------------------------------------------------------------------
# Bucket de comprobantes
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "comprobantes" {
  bucket = "${var.proyecto}-comprobantes-${var.ambiente}"
}

# Decisión 1: CKV_AWS_53, CKV_AWS_54, CKV_AWS_55, CKV_AWS_56 y CKV2_AWS_6 bloquean.
# Se restaura el bloqueo de acceso público que retiró el commit bd600fe.
resource "aws_s3_bucket_public_access_block" "comprobantes" {
  bucket = aws_s3_bucket.comprobantes.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Decisión 1: CKV_AWS_70 bloquea. El proveedor de conciliación lee con su rol,
# no con Principal "*".
resource "aws_s3_bucket_policy" "conciliacion" {
  bucket = aws_s3_bucket.comprobantes.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "LecturaConciliacion"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.cuenta_conciliacion}:role/${var.rol_conciliacion}" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.comprobantes.arn}/comprobantes/*"
      },
      {
        Sid       = "SoloTLS"
        Effect    = "Deny"
        Principal = { AWS = "*" }
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.comprobantes.arn,
          "${aws_s3_bucket.comprobantes.arn}/*",
        ]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.comprobantes]
}

# Decisión 1: CKV_AWS_18 bloquea. Sin registros de acceso no se pudo saber
# cuántos comprobantes se descargaron durante el incidente.
resource "aws_s3_bucket_logging" "comprobantes" {
  bucket        = aws_s3_bucket.comprobantes.id
  target_bucket = aws_s3_bucket.registros_acceso.id
  target_prefix = "comprobantes/"
}

# ---------------------------------------------------------------------------
# Bucket de registros de acceso
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "registros_acceso" {
  # Excepción EXC-02 (ver EXCEPCIONES.md): es el destino de los registros y no
  # puede registrarse a sí mismo.
  #checkov:skip=CKV_AWS_18:EXC-02 bucket destino de registros de acceso; no se registra a si mismo. Ver EXCEPCIONES.md
  bucket = "${var.proyecto}-registros-acceso-${var.ambiente}"
}

resource "aws_s3_bucket_public_access_block" "registros_acceso" {
  bucket = aws_s3_bucket.registros_acceso.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "registros_acceso" {
  bucket = aws_s3_bucket.registros_acceso.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EntregaDeRegistrosS3"
      Effect    = "Allow"
      Principal = { Service = "logging.s3.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.registros_acceso.arn}/comprobantes/*"
      Condition = {
        ArnLike      = { "aws:SourceArn" = aws_s3_bucket.comprobantes.arn }
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.actual.account_id }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.registros_acceso]
}
