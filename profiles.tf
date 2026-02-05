# Apply merged captive portal configurations to device profiles

# List of captive portal hosts to remove on destroy (for split tunnel excludes)
locals {
  captive_portal_hosts_json = jsonencode([for e in local.captive_portal_split_tunnel_excludes : e.host])
  captive_portal_suffixes_json = jsonencode([for d in local.captive_portal_local_domain_fallback : d.suffix])
}

# Update default profile split tunnel excludes (only if in exclude mode)
resource "null_resource" "default_split_tunnel_excludes" {
  count = local.default_needs_split_tunnel ? 1 : 0

  triggers = {
    excludes_hash    = sha256(jsonencode(local.default_merged_excludes))
    account_id       = var.cloudflare_account_id
    api_email        = var.cloudflare_api_email
    api_key          = var.cloudflare_api_key
    captive_hosts    = local.captive_portal_hosts_json
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

  # On destroy, remove only the captive portal entries
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Get current excludes
      CURRENT=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/accounts/${self.triggers.account_id}/devices/policy/exclude" \
        -H "X-Auth-Email: ${self.triggers.api_email}" \
        -H "X-Auth-Key: ${self.triggers.api_key}" \
        -H "Content-Type: application/json")

      # Filter out captive portal entries
      CAPTIVE_HOSTS='${self.triggers.captive_hosts}'
      FILTERED=$(echo "$CURRENT" | jq --argjson hosts "$CAPTIVE_HOSTS" '
        .result | map(select(.host as $h | ($h == null) or ($hosts | index($h) == null)))
      ')

      # Update with filtered list
      curl -s -X PUT \
        "https://api.cloudflare.com/client/v4/accounts/${self.triggers.account_id}/devices/policy/exclude" \
        -H "X-Auth-Email: ${self.triggers.api_email}" \
        -H "X-Auth-Key: ${self.triggers.api_key}" \
        -H "Content-Type: application/json" \
        -d "$FILTERED"
    EOT
  }
}

# Update default profile local domain fallback
resource "null_resource" "default_local_domain_fallback" {
  triggers = {
    ldf_hash         = sha256(jsonencode(local.default_merged_ldf))
    account_id       = var.cloudflare_account_id
    api_email        = var.cloudflare_api_email
    api_key          = var.cloudflare_api_key
    captive_suffixes = local.captive_portal_suffixes_json
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

  # On destroy, remove only the captive portal entries
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Get current LDF
      CURRENT=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/accounts/${self.triggers.account_id}/devices/policy/fallback_domains" \
        -H "X-Auth-Email: ${self.triggers.api_email}" \
        -H "X-Auth-Key: ${self.triggers.api_key}" \
        -H "Content-Type: application/json")

      # Filter out captive portal entries
      CAPTIVE_SUFFIXES='${self.triggers.captive_suffixes}'
      FILTERED=$(echo "$CURRENT" | jq --argjson suffixes "$CAPTIVE_SUFFIXES" '
        .result | map(select(.suffix as $s | ($suffixes | index($s) == null)))
      ')

      # Update with filtered list
      curl -s -X PUT \
        "https://api.cloudflare.com/client/v4/accounts/${self.triggers.account_id}/devices/policy/fallback_domains" \
        -H "X-Auth-Email: ${self.triggers.api_email}" \
        -H "X-Auth-Key: ${self.triggers.api_key}" \
        -H "Content-Type: application/json" \
        -d "$FILTERED"
    EOT
  }
}

# Update custom profile split tunnel excludes (only for profiles in exclude mode)
resource "null_resource" "custom_split_tunnel_excludes" {
  for_each = local.custom_profile_merged_excludes

  triggers = {
    excludes_hash    = sha256(jsonencode(each.value))
    policy_id        = each.key
    account_id       = var.cloudflare_account_id
    api_email        = var.cloudflare_api_email
    api_key          = var.cloudflare_api_key
    captive_hosts    = local.captive_portal_hosts_json
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

  # On destroy, remove only the captive portal entries
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Get current excludes
      CURRENT=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/accounts/${self.triggers.account_id}/devices/policy/${self.triggers.policy_id}/exclude" \
        -H "X-Auth-Email: ${self.triggers.api_email}" \
        -H "X-Auth-Key: ${self.triggers.api_key}" \
        -H "Content-Type: application/json")

      # Filter out captive portal entries
      CAPTIVE_HOSTS='${self.triggers.captive_hosts}'
      FILTERED=$(echo "$CURRENT" | jq --argjson hosts "$CAPTIVE_HOSTS" '
        .result | map(select(.host as $h | ($h == null) or ($hosts | index($h) == null)))
      ')

      # Update with filtered list
      curl -s -X PUT \
        "https://api.cloudflare.com/client/v4/accounts/${self.triggers.account_id}/devices/policy/${self.triggers.policy_id}/exclude" \
        -H "X-Auth-Email: ${self.triggers.api_email}" \
        -H "X-Auth-Key: ${self.triggers.api_key}" \
        -H "Content-Type: application/json" \
        -d "$FILTERED"
    EOT
  }
}

# Update custom profile local domain fallback
resource "null_resource" "custom_local_domain_fallback" {
  for_each = local.custom_profile_merged_ldf

  triggers = {
    ldf_hash         = sha256(jsonencode(each.value))
    policy_id        = each.key
    account_id       = var.cloudflare_account_id
    api_email        = var.cloudflare_api_email
    api_key          = var.cloudflare_api_key
    captive_suffixes = local.captive_portal_suffixes_json
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

  # On destroy, remove only the captive portal entries
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Get current LDF
      CURRENT=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/accounts/${self.triggers.account_id}/devices/policy/${self.triggers.policy_id}/fallback_domains" \
        -H "X-Auth-Email: ${self.triggers.api_email}" \
        -H "X-Auth-Key: ${self.triggers.api_key}" \
        -H "Content-Type: application/json")

      # Filter out captive portal entries
      CAPTIVE_SUFFIXES='${self.triggers.captive_suffixes}'
      FILTERED=$(echo "$CURRENT" | jq --argjson suffixes "$CAPTIVE_SUFFIXES" '
        .result | map(select(.suffix as $s | ($suffixes | index($s) == null)))
      ')

      # Update with filtered list
      curl -s -X PUT \
        "https://api.cloudflare.com/client/v4/accounts/${self.triggers.account_id}/devices/policy/${self.triggers.policy_id}/fallback_domains" \
        -H "X-Auth-Email: ${self.triggers.api_email}" \
        -H "X-Auth-Key: ${self.triggers.api_key}" \
        -H "Content-Type: application/json" \
        -d "$FILTERED"
    EOT
  }
}
