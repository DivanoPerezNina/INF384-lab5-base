variable "region" {
  type    = string
  default = "us-east-1"
}

variable "proyecto" {
  type    = string
  default = "monedero-andino"
}

variable "ambiente" {
  type    = string
  default = "prod"
}

variable "cuenta_conciliacion" {
  description = "Cuenta de AWS del proveedor de conciliación"
  type        = string
  default     = "111122223333"
}

variable "rol_conciliacion" {
  description = "Rol con el que el proveedor de conciliación lee los comprobantes"
  type        = string
  default     = "conciliacion-lectura"
}

variable "version_imagen" {
  type    = string
  default = "1.4.0"
}
