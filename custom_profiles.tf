# Fetch and process custom device profiles

# Build map of custom profiles by policy_id (empty if no profiles)
locals {
  custom_profiles_map = { for p in local.custom_profiles : p.policy_id => p if can(p.policy_id) }
}

# Fetch split tunnel and LDF data for each custom profile
data "http" "custom_profile_excludes" {
  for_each = local.custom_profiles_map

  url = "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/${each.key}/exclude"

  request_headers = {
    Authorization = "Bearer ${var.cloudflare_api_token}"
    Content-Type  = "application/json"
  }
}

data "http" "custom_profile_includes" {
  for_each = local.custom_profiles_map

  url = "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/${each.key}/include"

  request_headers = {
    Authorization = "Bearer ${var.cloudflare_api_token}"
    Content-Type  = "application/json"
  }
}

data "http" "custom_profile_ldf" {
  for_each = local.custom_profiles_map

  url = "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/${each.key}/fallback_domains"

  request_headers = {
    Authorization = "Bearer ${var.cloudflare_api_token}"
    Content-Type  = "application/json"
  }
}

# First pass: parse raw API responses
locals {
  custom_profile_raw = {
    for id, p in local.custom_profiles_map : id => {
      policy_id   = id
      name        = try(p.name, "")
      description = try(p.description, "")
      enabled     = try(p.enabled, true)
      precedence  = try(p.precedence, 100)
      match       = try(p.match, "")
      service_mode = try(p.service_mode_v2.mode, "warp")
      is_warp_mode = try(p.service_mode_v2.mode, "warp") == "warp"
      uses_cf_dns = contains(["warp", "proxy", "1dot1"], try(p.service_mode_v2.mode, "warp"))
      raw_excludes = try(jsondecode(data.http.custom_profile_excludes[id].response_body).result, null)
      raw_includes = try(jsondecode(data.http.custom_profile_includes[id].response_body).result, null)
      raw_ldf = try(jsondecode(data.http.custom_profile_ldf[id].response_body).result, null)
    }
  }
}

# Second pass: handle nulls and build final data
locals {
  custom_profile_data = {
    for id, p in local.custom_profile_raw : id => {
      policy_id   = p.policy_id
      name        = p.name
      description = p.description
      enabled     = p.enabled
      precedence  = p.precedence
      match       = p.match
      service_mode = p.service_mode
      is_warp_mode = p.is_warp_mode
      uses_cf_dns = p.uses_cf_dns
      existing_excludes = try([for e in p.raw_excludes : e], [])
      existing_includes = try([for i in p.raw_includes : i], [])
      existing_ldf = try([for d in p.raw_ldf : d], [])
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
