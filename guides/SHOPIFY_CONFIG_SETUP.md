# Shopify App Configuration Setup Guide

This guide explains how to manage different environments for your Shopify app using Shopify CLI.

## Configuration Files

### Development: `shopify.app.toml`

- Used for local development
- Points to `http://localhost:3000`
- Safe to commit to git
- Auto-updates URLs during `shopify app dev`

### Production: `shopify.app.production.toml`

- Used for production deployments
- Points to your production domain
- **NOT committed to git** (in `.gitignore`)
- Does not auto-update URLs (safer for production)

## Setup Instructions

### 1. Initial Setup for Production

```bash
# Link your production app (creates/updates shopify.app.production.toml)
shopify app config link

# When prompted:
# - Select "Create new app" or choose your existing production app
# - Name it "production"
# - This will populate the client_id automatically
```

### 2. Update Production URLs

Edit `shopify.app.production.toml` and update:

```toml
application_url = "https://your-actual-production-domain.com"

[auth]
redirect_urls = [
  "https://your-actual-production-domain.com/connections/auth/shopify/callback"
]
```

### 3. Working with Different Environments

#### Development (default):

```bash
# Run dev server
shopify app dev

# View current config
shopify app info
```

#### Production:

```bash
# Switch to production config
shopify app config use production

# Deploy to production
shopify app deploy

# Switch back to development
shopify app config use
# Then select your development config from the list
```

#### One-off Commands:

```bash
# Deploy to production without switching default
shopify app deploy --config production

# Release a specific version to production
shopify app release --version=v2.1.0 --config production
```

### 4. View Available Configs

```bash
# List all app versions
shopify app versions list

# Show environment details
shopify app env show

# Pull environment variables
shopify app env pull
```

## Important Notes

### Security

- ✅ `shopify.app.toml` - **Committed to git** (development only)
- ❌ `shopify.app.production.toml` - **NOT committed** (contains production client_id)
- ❌ `.env*` files - **NOT committed** (contains access tokens)

### Scope Updates

Both files now use the minimal required scopes:

```toml
[access_scopes]
scopes = "read_products,write_products,read_orders,read_merchant_managed_fulfillment_orders,write_merchant_managed_fulfillment_orders"
```

### After Scope Changes

When you deploy scope changes:

1. Existing merchant installations will need to **re-authenticate**
2. They'll go through OAuth flow again when they next access the app
3. Test on a development store first!

## Deployment Workflow

### Standard Deployment

```bash
# 1. Make your code changes
# 2. Test locally
shopify app dev

# 3. Deploy to production
shopify app config use production
shopify app deploy --version="v2.1.0" --message="Updated access scopes"

# 4. Switch back to development
shopify app config use
```

### With CI/CD

```bash
# In your CI/CD pipeline
shopify app deploy --config production --force --version=$CI_COMMIT_TAG
```

## Troubleshooting

### "Config not found" error

```bash
# Re-link your configuration
shopify app config link
```

### URLs not matching

```bash
# Verify your current config
shopify app info

# Update URLs in your TOML file
# Then deploy
shopify app deploy
```

### Multiple developers

Each developer should:

1. Have their own `shopify.app.toml` (or `shopify.app.dev.toml`)
2. Link to their own development app
3. Never commit production configs

## Quick Reference

| Command                                  | Purpose                                  |
| ---------------------------------------- | ---------------------------------------- |
| `shopify app config link`                | Create/link a new config                 |
| `shopify app config use <name>`          | Switch default config                    |
| `shopify app dev`                        | Start dev server (uses default config)   |
| `shopify app deploy`                     | Deploy app version (uses default config) |
| `shopify app deploy --config production` | Deploy to specific config                |
| `shopify app info`                       | View current configuration               |
| `shopify app versions list`              | List all app versions                    |

## Learn More

- [App Configuration Documentation](https://shopify.dev/docs/apps/build/cli-for-apps/app-configuration)
- [Deploy App Versions](https://shopify.dev/docs/apps/launch/deployment/deploy-app-versions)
- [Manage App Config Files](https://shopify.dev/docs/apps/build/cli-for-apps/manage-app-config-files)
