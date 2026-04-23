variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare scoped API token with Zero Trust Edit permission"
  type        = string
  sensitive   = true
}
