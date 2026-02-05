# Apply merged captive portal configurations to device profiles

# Update default profile split tunnel excludes (only if in exclude mode)
resource "null_resource" "default_split_tunnel_excludes" {
  count = local.default_needs_split_tunnel ? 1 : 0

  triggers = {
    excludes_hash = sha256(jsonencode(local.default_merged_excludes))
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -s -X PUT \
        "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/exclude" \
        -H "X-Auth-Email: ${var.cloudflare_api_email}" \
        -H "X-Auth-Key: ${var.cloudflare_api_key}" \
        -H "Content-Type: application/json" \
        -d '${jsonencode(local.default_merged_excludes)}'
    EOT
  }
}

# Update default profile local domain fallback
resource "null_resource" "default_local_domain_fallback" {
  triggers = {
    ldf_hash = sha256(jsonencode(local.default_merged_ldf))
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -s -X PUT \
        "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/fallback_domains" \
        -H "X-Auth-Email: ${var.cloudflare_api_email}" \
        -H "X-Auth-Key: ${var.cloudflare_api_key}" \
        -H "Content-Type: application/json" \
        -d '${jsonencode(local.default_merged_ldf)}'
    EOT
  }
}

# Update custom profile split tunnel excludes (only for profiles in exclude mode)
resource "null_resource" "custom_split_tunnel_excludes" {
  for_each = local.custom_profile_merged_excludes

  triggers = {
    excludes_hash = sha256(jsonencode(each.value))
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -s -X PUT \
        "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/${each.key}/exclude" \
        -H "X-Auth-Email: ${var.cloudflare_api_email}" \
        -H "X-Auth-Key: ${var.cloudflare_api_key}" \
        -H "Content-Type: application/json" \
        -d '${jsonencode(each.value)}'
    EOT
  }
}

# Update custom profile local domain fallback
resource "null_resource" "custom_local_domain_fallback" {
  for_each = local.custom_profile_merged_ldf

  triggers = {
    ldf_hash = sha256(jsonencode(each.value))
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -s -X PUT \
        "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/${each.key}/fallback_domains" \
        -H "X-Auth-Email: ${var.cloudflare_api_email}" \
        -H "X-Auth-Key: ${var.cloudflare_api_key}" \
        -H "Content-Type: application/json" \
        -d '${jsonencode(each.value)}'
    EOT
  }
}
