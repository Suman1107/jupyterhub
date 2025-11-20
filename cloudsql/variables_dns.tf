variable "dns_domain" {
  description = "Domain name for the DNS zone (e.g., example.com)"
  type        = string
  default     = "jupyterhub-proxy.com" # Change this to a domain you own
}
