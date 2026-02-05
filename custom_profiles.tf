# Fetch and process custom device profiles

# Fetch split tunnel and LDF data for each custom profile
data "http" "custom_profile_excludes" {
  for_each = { for p in local.custom_profiles : p.policy_id => p }

  url = "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/${each.key}/exclude"

  request_headers = {
    X-Auth-Email = var.cloudflare_api_email
    X-Auth-Key   = var.cloudflare_api_key
    Content-Type = "application/json"
  }
}

data "http" "custom_profile_includes" {
  for_each = { for p in local.custom_profiles : p.policy_id => p }

  url = "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/${each.key}/include"

  request_headers = {
    X-Auth-Email = var.cloudflare_api_email
    X-Auth-Key   = var.cloudflare_api_key
    Content-Type = "application/json"
  }
}

data "http" "custom_profile_ldf" {
  for_each = { for p in local.custom_profiles : p.policy_id => p }

  url = "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/${each.key}/fallback_domains"

  request_headers = {
    X-Auth-Email = var.cloudflare_api_email
    X-Auth-Key   = var.cloudflare_api_key
    Content-Type = "application/json"
  }
}

locals {
  # Process each custom profile
  custom_profile_data = {
    for p in local.custom_profiles : p.policy_id => {
      policy_id   = p.policy_id
      name        = p.name
      description = try(p.description, "")
      enabled     = try(p.enabled, true)
      precedence  = try(p.precedence, 100)
      match       = try(p.match, "")

      # Service mode determines what we need to update
      service_mode = try(p.service_mode_v2.mode, "warp")
      # Split tunnels only apply to warp mode (full tunnel)
      is_warp_mode = try(p.service_mode_v2.mode, "warp") == "warp"
      # LDF applies to modes that use Cloudflare DNS (warp, proxy, 1dot1) but NOT warp_tunnel_only
      uses_cf_dns = contains(["warp", "proxy", "1dot1"], try(p.service_mode_v2.mode, "warp"))

      # Parse existing excludes
      existing_excludes = try(jsondecode(data.http.custom_profile_excludes[p.policy_id].response_body).result, [])

      # Parse existing includes
      existing_includes = try(jsondecode(data.http.custom_profile_includes[p.policy_id].response_body).result, [])

      # Parse existing LDF
      existing_ldf = try(jsondecode(data.http.custom_profile_ldf[p.policy_id].response_body).result, [])
    }
  }

  # Determine which profiles need split tunnel updates (warp mode + exclude mode)
  custom_profiles_needing_split_tunnel = {
    for id, p in local.custom_profile_data : id => p
    if p.is_warp_mode && (length(p.existing_excludes) > 0 || length(p.existing_includes) == 0)
  }

  # Only profiles using Cloudflare DNS need LDF updates (warp, proxy, 1dot1 - NOT warp_tunnel_only)
  custom_profiles_needing_ldf = {
    for id, p in local.custom_profile_data : id => p
    if p.uses_cf_dns
  }

  # Build merged configurations for each custom profile
  custom_profile_merged_config = {
    for id, p in local.custom_profile_data : id => {
      policy_id   = p.policy_id
      name        = p.name
      description = p.description
      enabled     = p.enabled
      precedence  = p.precedence
      match       = p.match

      # Existing exclude hosts for deduplication
      existing_exclude_hosts = toset([
        for e in p.existing_excludes : try(e.host, "") if try(e.host, "") != ""
      ])

      # Existing LDF suffixes for deduplication
      existing_ldf_suffixes = toset([
        for d in p.existing_ldf : try(d.suffix, "") if try(d.suffix, "") != ""
      ])

      # Whether to update split tunnels (warp mode + exclude mode)
      needs_split_tunnel = p.is_warp_mode && (length(p.existing_excludes) > 0 || length(p.existing_includes) == 0)

      # Whether to update LDF (only if using CF DNS)
      needs_ldf = p.uses_cf_dns

      # Existing excludes (formatted for terraform resource)
      existing_excludes_formatted = [
        for e in p.existing_excludes : {
          address     = try(e.address, null)
          host        = try(e.host, null)
          description = try(e.description, null)
        }
      ]

      # Existing LDF (formatted for terraform resource)
      existing_ldf_formatted = [
        for d in p.existing_ldf : {
          suffix      = try(d.suffix, null)
          description = try(d.description, null)
          dns_server  = try(d.dns_server, null)
        }
      ]
    }
  }

  # Final merged excludes for each profile
  custom_profile_merged_excludes = {
    for id, p in local.custom_profile_merged_config : id => concat(
      p.existing_excludes_formatted,
      [
        for e in local.captive_portal_split_tunnel_excludes :
        e if !contains(p.existing_exclude_hosts, e.host)
      ]
    ) if p.needs_split_tunnel
  }

  # Final merged LDF for each profile (only for profiles using CF DNS)
  custom_profile_merged_ldf = {
    for id, p in local.custom_profile_merged_config : id => concat(
      p.existing_ldf_formatted,
      [
        for d in local.captive_portal_local_domain_fallback :
        d if !contains(p.existing_ldf_suffixes, d.suffix)
      ]
    ) if p.needs_ldf
  }
}
