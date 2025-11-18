# Shopify OAuth Migration - Next Steps

## ✅ Code Changes Complete

The application has been updated to use Shopify's OAuth install URL instead of manual shop domain entry. The "Connect Shopify" button now redirects directly to:

```
https://admin.shopify.com/oauth/install?client_id=YOUR_CLIENT_ID
```

This complies with Shopify's App Store requirement that apps must not request manual entry of myshopify.com URLs.

## 📋 Required Manual Steps

### 1. Update Shopify Partner Dashboard

**CRITICAL:** The App URL must point to your connect endpoint for the OAuth flow to work properly.

#### For Development App:

1. Go to [Shopify Partners](https://partners.shopify.com/)
2. Navigate to: Apps → [Your Development App] → Configuration
3. Under "App URL", set it to: `http://localhost:3000/connections/shopify/connect`
   - ⚠️ This is crucial! Shopify will redirect here with the shop parameter
4. Under "Allowed redirection URL(s)", ensure you have:
   ```
   http://localhost:3000/connections/auth/shopify/callback
   ```

#### For Production App:

1. Go to [Shopify Partners](https://partners.shopify.com/)
2. Navigate to: Apps → [Your Production App] → Configuration
3. Under "App URL", set it to: `https://your-domain.com/connections/shopify/connect`
   - ⚠️ This is crucial! Shopify will redirect here with the shop parameter
4. Under "Allowed redirection URL(s)", ensure you have:
   ```
   https://your-domain.com/connections/auth/shopify/callback
   ```

### 2. Environment Variables

Ensure these environment variables are set:

**Development (.env):**

```bash
SHOPIFY_API_KEY=your_dev_api_key
SHOPIFY_API_SECRET=your_dev_api_secret
SHOPIFY_HOST=localhost:3000
```

**Production:**

```bash
SHOPIFY_API_KEY=your_production_api_key
SHOPIFY_API_SECRET=your_production_api_secret
SHOPIFY_HOST=your-production-domain.com
```

## 🧪 Testing the New Flow

### Development Testing:

1. **Start your development server:**

   ```bash
   bin/dev
   ```

2. **Login to your app** (if required)

3. **Navigate to the connections dashboard:**

   ```
   http://localhost:3000/connections
   ```

4. **Click "Connect Shopify" button**
   - You should be redirected to `https://admin.shopify.com/oauth/install?client_id=...`
   - If you're logged into a Shopify store, it will auto-detect that store
   - If you're not logged in, Shopify will prompt you to choose a store or login
5. **Approve the permissions**

   - Shopify will show the scopes your app is requesting:
     - Read products
     - Write products
     - Read orders
     - Read merchant managed fulfillment orders
     - Write merchant managed fulfillment orders

6. **Verify redirect back to your app**
   - After approval, you should be redirected to: `http://localhost:3000/connections/auth/shopify/callback`
   - The ShopifyApp engine will process the callback
   - You should end up at the connections dashboard with the store connected

### What Changed:

**Before:**

```
User clicks "Connect Shopify"
  → Redirected to /connections/login (ShopifyApp form)
  → User manually types "store-name.myshopify.com"
  → Redirected to Shopify OAuth
  → Approve permissions
  → Callback to app
```

**After (Two-Step OAuth Flow):**

```
User clicks "Connect Shopify"
  → Step 1: Redirected to https://admin.shopify.com/oauth/install?client_id=...
  → Shopify detects logged-in store OR prompts to choose
  → Step 2: Shopify redirects to App URL with ?shop=store-name.myshopify.com
  → App catches shop parameter and redirects to https://store-name.myshopify.com/admin/oauth/authorize?...
  → User approves permissions
  → Shopify redirects to callback URL
  → ShopifyApp engine creates store session
  → User redirected to connections dashboard
```

**Why Two Steps?**
The `https://admin.shopify.com/oauth/install` endpoint doesn't directly handle OAuth. Instead, it:

1. Detects which store the merchant wants to install the app on (or prompts them to choose)
2. Redirects to your App URL with the `shop` parameter
3. Your app then initiates the actual OAuth flow with that specific shop

## 🎯 Benefits

- ✅ **Complies with Shopify App Store requirements** - No manual URL entry
- ✅ **Better UX** - One less step, no typing required
- ✅ **Automatic store detection** - Works with logged-in merchants
- ✅ **Standard app installation flow** - Matches other Shopify apps

## 🔍 Troubleshooting

### Issue: "Redirect URL not allowed"

**Cause:** The callback URL in your Shopify Partner Dashboard doesn't match the one configured in the app.

**Solution:**

- Check that your Partner Dashboard has the correct callback URL
- Ensure it matches: `YOUR_HOST/connections/auth/shopify/callback`

### Issue: "Client ID not found"

**Cause:** The `SHOPIFY_API_KEY` environment variable is not set or incorrect.

**Solution:**

- Verify `ENV['SHOPIFY_API_KEY']` is set correctly
- Check your `.env` file (development) or production environment variables

### Issue: OAuth flow completes but store isn't connected

**Cause:** The callback handler or session storage might have an issue.

**Solution:**

- Check Rails logs for errors during the callback
- Verify the `Store` model is correctly implementing `ShopifyApp::SessionStorage`
- Ensure the user is logged in (the `Store` needs to be associated with a `User`)

## 🔒 Security Note

The `connect` action now handles the shop parameter that Shopify sends. This parameter includes HMAC verification data (`hmac`, `timestamp`) that should be validated to ensure the request actually came from Shopify. The ShopifyApp gem handles this validation in the callback, but for extra security, you could add HMAC validation in the connect action as well.

## 📚 Related Files Modified

- `app/controllers/connections/shopify/auth_controller.rb` - Implemented two-step OAuth flow:
  - Step 1: Redirect to `https://admin.shopify.com/oauth/install`
  - Step 2: Catch shop parameter and initiate OAuth with specific store

## 📖 Additional Resources

- [Shopify OAuth Documentation](https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/authorization-code-grant)
- [Shopify App Store Requirements](https://shopify.dev/docs/apps/store/requirements)
