variable "db_password" {
  description = "Password for the proxy_admin database user"
  type        = string
  default     = "postgres" # Change this in production!
}
