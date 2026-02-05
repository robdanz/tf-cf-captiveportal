# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
terraform init          # Initialize providers (run after cloning)
terraform plan          # Preview changes
terraform apply         # Apply changes to Cloudflare
terraform destroy       # Remove captive portal entries (clean removal)
terraform plan -parallelism=1  # Use if hitting API rate limits
```

## Architecture

This Terraform project manages Cloudflare WARP device profile settings via direct API calls (not the Cloudflare provider resources) to support merge-not-replace behavior.

### Data Flow

1. **data.tf** - Fetches existing settings via HTTP data sources:
   - Default device profile and its split tunnel/LDF entries
   - List of all custom device profiles
   - Uses two-pass locals pattern to handle null API responses

2. **custom_profiles.tf** - For each custom profile:
   - Fetches exclude/include/LDF entries via HTTP
   - Determines update needs based on service mode (`warp`, `proxy`, `1dot1`, `warp_tunnel_only`)
   - Builds merged configurations (existing + captive portal entries)

3. **locals.tf** - Static captive portal domain lists:
   - `captive_portal_split_tunnel_excludes` - Wildcard hosts (e.g., `*.deltawifi.com`)
   - `captive_portal_local_domain_fallback` - Domain suffixes (e.g., `deltawifi.com`)

4. **profiles.tf** - Applies changes via `null_resource` with `local-exec`:
   - Uses curl to PUT merged entries to Cloudflare API
   - Destroy provisioners remove only captive portal entries (requires `jq`)

### Service Mode Logic

| Mode | Split Tunnels | LDF |
|------|--------------|-----|
| `warp` (exclude mode) | ✓ | ✓ |
| `warp` (include mode) | ✗ | ✓ |
| `proxy` | ✗ | ✓ |
| `1dot1` | ✗ | ✓ |
| `warp_tunnel_only` | ✗ | ✗ |

### Key Patterns

- **Null handling**: API may return `null` instead of `[]`. Use `try([for x in raw : x], [])` pattern.
- **Deduplication**: Existing entries are tracked via `toset()` of hosts/suffixes to avoid duplicates.
- **Merge behavior**: New entries are `concat()`ed with existing, never replacing.

## Adding Captive Portal Domains

Edit `locals.tf`:
- Add to `captive_portal_split_tunnel_excludes` with `*.domain.com` format
- Add to `captive_portal_local_domain_fallback` with `domain.com` format
