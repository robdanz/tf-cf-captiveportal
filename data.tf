# Fetch existing device profiles from Cloudflare API

# Get the default device profile settings
data "http" "default_profile" {
  url = "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy"

  request_headers = {
    X-Auth-Email = var.cloudflare_api_email
    X-Auth-Key   = var.cloudflare_api_key
    Content-Type = "application/json"
  }
}

# Get default profile split tunnel excludes
data "http" "default_split_tunnel_excludes" {
  url = "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/exclude"

  request_headers = {
    X-Auth-Email = var.cloudflare_api_email
    X-Auth-Key   = var.cloudflare_api_key
    Content-Type = "application/json"
  }
}

# Get default profile split tunnel includes
data "http" "default_split_tunnel_includes" {
  url = "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/include"

  request_headers = {
    X-Auth-Email = var.cloudflare_api_email
    X-Auth-Key   = var.cloudflare_api_key
    Content-Type = "application/json"
  }
}

# Get default profile local domain fallback
data "http" "default_local_domain_fallback" {
  url = "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policy/fallback_domains"

  request_headers = {
    X-Auth-Email = var.cloudflare_api_email
    X-Auth-Key   = var.cloudflare_api_key
    Content-Type = "application/json"
  }
}

# Get all custom device profiles
data "http" "custom_profiles" {
  url = "https://api.cloudflare.com/client/v4/accounts/${var.cloudflare_account_id}/devices/policies"

  request_headers = {
    X-Auth-Email = var.cloudflare_api_email
    X-Auth-Key   = var.cloudflare_api_key
    Content-Type = "application/json"
  }
}

locals {
  # Parse the default profile response
  default_profile_response = jsondecode(data.http.default_profile.response_body)
  default_profile          = local.default_profile_response.result

  # Parse split tunnel excludes for default profile
  default_excludes_response = jsondecode(data.http.default_split_tunnel_excludes.response_body)
  default_existing_excludes = try(local.default_excludes_response.result, [])

  # Parse split tunnel includes for default profile
  default_includes_response = jsondecode(data.http.default_split_tunnel_includes.response_body)
  default_existing_includes = try(local.default_includes_response.result, [])

  # Parse local domain fallback for default profile
  default_ldf_response     = jsondecode(data.http.default_local_domain_fallback.response_body)
  default_existing_ldf     = try(local.default_ldf_response.result, [])

  # Parse custom profiles response
  custom_profiles_response = jsondecode(data.http.custom_profiles.response_body)
  custom_profiles          = try(local.custom_profiles_response.result, [])

  # Determine if default profile needs split tunnel updates
  # service_mode_v2.mode = "warp" means Traffic and DNS mode
  # split_tunnel_mode determines include vs exclude
  default_is_warp_mode    = try(local.default_profile.service_mode_v2.mode, "warp") == "warp"
  default_is_exclude_mode = length(local.default_existing_excludes) > 0 || length(local.default_existing_includes) == 0
  default_needs_split_tunnel = local.default_is_warp_mode && local.default_is_exclude_mode

  # Create a set of existing exclude hosts to avoid duplicates
  default_existing_exclude_hosts = toset([
    for e in local.default_existing_excludes : try(e.host, "") if try(e.host, "") != ""
  ])

  # Create a set of existing LDF suffixes to avoid duplicates
  default_existing_ldf_suffixes = toset([
    for d in local.default_existing_ldf : try(d.suffix, "") if try(d.suffix, "") != ""
  ])

  # Filter captive portal excludes to only include new ones
  default_new_split_tunnel_excludes = [
    for e in local.captive_portal_split_tunnel_excludes :
    e if !contains(local.default_existing_exclude_hosts, e.host)
  ]

  # Filter captive portal LDF to only include new ones
  default_new_ldf_entries = [
    for d in local.captive_portal_local_domain_fallback :
    d if !contains(local.default_existing_ldf_suffixes, d.suffix)
  ]

  # Merged split tunnel excludes for default profile
  default_merged_excludes = local.default_needs_split_tunnel ? concat(
    [for e in local.default_existing_excludes : {
      address     = try(e.address, null)
      host        = try(e.host, null)
      description = try(e.description, null)
    }],
    local.default_new_split_tunnel_excludes
  ) : local.default_existing_excludes

  # Merged LDF entries for default profile (always update unless not using CF DNS)
  default_merged_ldf = concat(
    [for d in local.default_existing_ldf : {
      suffix      = try(d.suffix, null)
      description = try(d.description, null)
      dns_server  = try(d.dns_server, null)
    }],
    local.default_new_ldf_entries
  )
}
