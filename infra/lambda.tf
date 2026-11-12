resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${var.proyecto}-api-${var.ambiente}"
  retention_in_days = 7
}

resource "aws_lambda_function" "api" {
  function_name = "${var.proyecto}-api-${var.ambiente}"
  role          = aws_iam_role.api.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.api.repository_url}:${var.version_imagen}"
  timeout       = 10
  memory_size   = 256

  # Control compensatorio de la excepción EXC-01 (Function URL sin autenticación):
  # limita cuántas invocaciones concurrentes puede provocar un abuso de la URL.
  reserved_concurrent_executions = 50

  environment {
    variables = {
      BUCKET_COMPROBANTES = aws_s3_bucket.comprobantes.bucket
    }
  }

  lifecycle {
    ignore_changes = [image_uri]
  }

  depends_on = [aws_cloudwatch_log_group.api]
}

resource "aws_lambda_function_url" "api" {
  # Excepción EXC-01 (Decisión 3, ver EXCEPCIONES.md). Vence el 2026-12-11.
  #checkov:skip=CKV_AWS_258:EXC-01 la app movil consume la URL sin firma SigV4. Responsable Lider tecnico. Vence 2026-12-11. Ver EXCEPCIONES.md
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "NONE"
}
