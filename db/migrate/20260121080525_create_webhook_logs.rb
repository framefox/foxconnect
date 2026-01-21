class CreateWebhookLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_logs do |t|
      t.string :topic, null: false           # e.g., "orders/create", "app/uninstalled"
      t.string :shop_domain                   # X-Shopify-Shop-Domain header
      t.references :store, null: true, foreign_key: true  # Link to store if found
      t.integer :status_code, null: false, default: 0     # HTTP response code (200, 404, 500, etc.)
      t.string :webhook_id                    # X-Shopify-Webhook-Id for deduplication
      t.text :error_message                   # Error details if failed
      t.json :headers                         # Relevant Shopify headers
      t.text :payload_ciphertext              # Encrypted webhook payload (contains PII)
      t.integer :processing_time_ms           # How long processing took

      t.timestamps
    end

    add_index :webhook_logs, :topic
    add_index :webhook_logs, :shop_domain
    add_index :webhook_logs, :status_code
    add_index :webhook_logs, :webhook_id, unique: true
    add_index :webhook_logs, :created_at
  end
end
