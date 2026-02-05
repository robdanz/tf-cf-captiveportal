# Outputs for visibility into what was applied

output "default_profile_status" {
  description = "Status of the default device profile configuration"
  value = {
    service_mode                = try(local.default_profile.service_mode_v2.mode, "unknown")
    split_tunnel_mode           = local.default_is_exclude_mode ? "exclude" : "include"
    split_tunnel_updated        = local.default_needs_split_tunnel
    existing_excludes_count     = length(local.default_existing_excludes)
    new_excludes_added          = length(local.default_new_split_tunnel_excludes)
    total_excludes              = local.default_needs_split_tunnel ? length(local.default_merged_excludes) : length(local.default_existing_excludes)
    existing_ldf_count          = length(local.default_existing_ldf)
    new_ldf_added               = length(local.default_new_ldf_entries)
    total_ldf                   = length(local.default_merged_ldf)
  }
}

output "custom_profiles_status" {
  description = "Status of each custom device profile configuration"
  value = {
    for id, p in local.custom_profile_merged_config : p.name => {
      policy_id                   = id
      service_mode                = local.custom_profile_data[id].service_mode
      uses_cf_dns                 = local.custom_profile_data[id].uses_cf_dns
      split_tunnel_updated        = p.needs_split_tunnel
      ldf_updated                 = p.needs_ldf
      existing_excludes_count     = length(local.custom_profile_data[id].existing_excludes)
      new_excludes_added          = p.needs_split_tunnel ? length([for e in local.captive_portal_split_tunnel_excludes : e if !contains(p.existing_exclude_hosts, e.host)]) : 0
      total_excludes              = p.needs_split_tunnel ? length(try(local.custom_profile_merged_excludes[id], [])) : length(local.custom_profile_data[id].existing_excludes)
      existing_ldf_count          = length(local.custom_profile_data[id].existing_ldf)
      new_ldf_added               = p.needs_ldf ? length([for d in local.captive_portal_local_domain_fallback : d if !contains(p.existing_ldf_suffixes, d.suffix)]) : 0
      total_ldf                   = p.needs_ldf ? length(try(local.custom_profile_merged_ldf[id], [])) : length(local.custom_profile_data[id].existing_ldf)
    }
  }
}

output "captive_portal_entries_summary" {
  description = "Summary of captive portal entries being managed"
  value = {
    split_tunnel_exclude_count  = length(local.captive_portal_split_tunnel_excludes)
    local_domain_fallback_count = length(local.captive_portal_local_domain_fallback)
  }
}
