# Cloudflare WARP Captive Portal Configuration

This Terraform configuration automatically adds captive portal domains to Cloudflare WARP device profiles to ensure users can connect to WiFi captive portals (airlines, hotels, etc.) while WARP is enabled.

## What This Does

For each WARP device profile in your account, this configuration:

1. **Split Tunnel Exclusions**: Adds captive portal domains to the exclude list (only if the profile is in "Traffic and DNS" mode with "Exclude IPs and domains" split tunnel mode)

2. **Local Domain Fallback**: Adds captive portal domain suffixes to ensure DNS resolution works correctly (for all profiles using Cloudflare DNS)

### Logic Summary

| Service Mode | Split Tunnel Mode | Update Split Tunnels | Update LDF |
|--------------|-------------------|---------------------|------------|
| Traffic and DNS (`warp`) | Exclude | Yes | Yes |
| Traffic and DNS (`warp`) | Include | No | Yes |
| DNS only (`proxy`) | N/A | No | Yes |

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- Cloudflare account with Zero Trust enabled
- API credentials with Zero Trust Write permissions

## Usage

1. Clone this repository:
   ```bash
   git clone https://github.com/robdanz/tf-cf-captiveportal.git
   cd tf-cf-captiveportal
   ```

2. Copy the example variables file and fill in your credentials:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` with your Cloudflare credentials:
   ```hcl
   cloudflare_account_id = "your-account-id"
   cloudflare_api_email  = "your-email@example.com"
   cloudflare_api_key    = "your-global-api-key"
   ```

4. Initialize Terraform:
   ```bash
   terraform init
   ```

5. Preview the changes:
   ```bash
   terraform plan
   ```

6. Apply the configuration:
   ```bash
   terraform apply
   ```

## Important Notes

- **Merge, Not Replace**: This configuration **merges** captive portal entries with your existing entries. It will never delete entries you've already configured.

- **Idempotent**: Running `terraform apply` multiple times is safe. Entries are deduplicated, so running it again won't create duplicates.

- **Sensitive Data**: Never commit `terraform.tfvars` to version control. It contains your API credentials.

## Captive Portal Domains

The captive portal domains are defined in `locals.tf` and sourced from:

- **CAPTIVE.md**: Split tunnel exclusion domains (with wildcards)
- **LDF.md**: Local domain fallback suffixes

### Supported Captive Portals

Airlines: Air Canada, Alaska, American, ANA, Breeze, Cathay Pacific, Delta, Emirates, Etihad, EVA, Iceland Air, JAL, JetBlue, Lufthansa, Norwegian, Southwest, United, Virgin Atlantic

Services: Amtrak, AT&T WiFi, Boingo, GoGo Inflight, IHG Hotels, Viasat, and more

## Adding New Captive Portal Domains

To add new captive portal domains:

1. Add the domain to `locals.tf` in the appropriate list:
   - `captive_portal_split_tunnel_excludes` - for split tunnel (use `*.domain.com` format)
   - `captive_portal_local_domain_fallback` - for LDF (use base domain format)

2. Run `terraform apply`

## Outputs

After applying, Terraform will output:

- Status of default profile configuration
- Status of each custom profile configuration
- Summary of captive portal entries managed

## Troubleshooting

### "API error" during apply

Ensure your API key has Zero Trust Write permissions. You can verify by checking the API tokens page in the Cloudflare dashboard.

### Changes not appearing in dashboard

The Cloudflare dashboard may cache settings. Try refreshing or waiting a few moments.

### Duplicate entries appearing

This shouldn't happen with normal operation. If it does, the configuration will deduplicate on the next run.

## License

MIT
