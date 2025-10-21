# Product Sync Scheduling Setup

This guide explains how to schedule the hourly product sync task for your Shopify app.

## How It Works

1. **Webhooks mark stores for sync**: When a merchant creates/updates a product, the webhook sets `products_last_updated_at` on the store
2. **Hourly task syncs marked stores**: A scheduled task runs every hour and syncs products for stores updated in the last hour
3. **Automatic debouncing**: Multiple product updates within an hour trigger only ONE sync

## Scheduling Options

### Option 1: Kamal Cron (Recommended for Your Setup)

Since you're using Kamal for deployment, add this to your `config/deploy.yml`:

```yaml
# config/deploy.yml
cron:
  jobs:
    - name: product_sync
      schedule: "0 * * * *" # Every hour on the hour
      command: "bundle exec rake products:sync_updated"
```

Then deploy:

```bash
kamal deploy
```

### Option 2: System Cron (Manual Setup)

Add to your server's crontab:

```bash
# SSH into your server
ssh your-server

# Edit crontab
crontab -e

# Add this line:
0 * * * * cd /var/www/foxconnect/current && bundle exec rake products:sync_updated RAILS_ENV=production >> /var/www/foxconnect/current/log/cron.log 2>&1
```

### Option 3: Sidekiq Cron (Requires Additional Gem)

If you want to manage scheduled jobs through Sidekiq UI:

1. Add to `Gemfile`:

```ruby
gem "sidekiq-cron"
```

2. Create `app/workers/product_sync_worker.rb`:

```ruby
class ProductSyncWorker
  include Sidekiq::Worker

  def perform
    # Call the rake task logic or inline it here
    system("bundle exec rake products:sync_updated")
  end
end
```

3. Create `config/schedule.yml`:

```yaml
product_sync:
  cron: "0 * * * *"
  class: "ProductSyncWorker"
  description: "Sync products for stores with recent updates"
```

4. Load in `config/initializers/sidekiq.rb`:

```ruby
require 'sidekiq/cron'
Sidekiq::Cron::Job.load_from_hash YAML.load_file('config/schedule.yml')
```

## Testing the Rake Task

### Manual Test:

```bash
# Run the sync task manually
rails products:sync_updated
```

### Test with Sample Data:

```ruby
# Rails console
rails c

# Mark a store for sync
store = Store.first
store.update(products_last_updated_at: 30.minutes.ago)

# Exit and run the task
exit
rails products:sync_updated

# Should show: "Found 1 store(s) with recent product updates"
```

### Test the Webhooks:

```bash
# Create a product webhook
curl -X POST http://localhost:3000/webhooks/products/create \
  -H "X-Shopify-Shop-Domain: test-store.myshopify.com" \
  -H "Content-Type: application/json" \
  -d '{"id": 12345, "title": "Test Product"}'

# Check the store was marked
rails c
Store.find_by(shopify_domain: "test-store.myshopify.com").products_last_updated_at
# Should show the current timestamp
```

## Monitoring

### Check Cron Logs:

```bash
# If using system cron
tail -f /var/www/foxconnect/current/log/cron.log

# Rails production logs
tail -f /var/www/foxconnect/current/log/production.log
```

### View Recent Syncs:

```sql
-- In rails console
Store.where.not(products_last_updated_at: nil)
     .order(products_last_updated_at: :desc)
     .limit(10)
     .pluck(:name, :products_last_updated_at)
```

## Adjusting the Sync Window

If you want to change from 1 hour to a different interval:

**Edit `lib/tasks/products.rake`:**

```ruby
# Change this line:
one_hour_ago = 1.hour.ago

# To something else:
thirty_minutes_ago = 30.minutes.ago  # More frequent
two_hours_ago = 2.hours.ago          # Less frequent
```

**Update the cron schedule accordingly:**

```
0 * * * *     # Every hour (current)
*/30 * * * *  # Every 30 minutes
0 */2 * * *   # Every 2 hours
```

## Production Deployment Checklist

- [ ] Migration has been run: `rails db:migrate`
- [ ] Webhook controller is deployed
- [ ] Rake task is deployed
- [ ] Cron job is configured (Kamal or system cron)
- [ ] Test webhook endpoint is accessible
- [ ] Test rake task runs successfully
- [ ] Monitor logs for first few executions

## Troubleshooting

### "No stores need product sync"

- Check that stores have `products_last_updated_at` set
- Verify the timestamp is within the last hour
- Test by manually setting timestamp on a store

### Webhooks not triggering

- Verify webhook routes are accessible
- Check HMAC verification isn't blocking requests
- Verify shop domain matches exactly in database

### Sync failures

- Check Shopify API credentials for the store
- Verify store has valid shopify_token
- Check API rate limits
