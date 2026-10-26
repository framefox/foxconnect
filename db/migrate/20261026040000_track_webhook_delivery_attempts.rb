class TrackWebhookDeliveryAttempts < ActiveRecord::Migration[8.0]
  def change
    add_column :webhook_logs, :delivery_state, :string, null: false, default: "pending"
    add_column :webhook_logs, :delivery_attempts, :integer, null: false, default: 0
    add_column :webhook_logs, :delivery_subject_id, :string
    add_column :webhook_logs, :delivery_job_id, :string
    add_column :webhook_logs, :next_attempt_at, :datetime
    add_column :webhook_logs, :retired_at, :datetime
    add_column :webhook_logs, :retired_by_user_id, :bigint
    add_column :webhook_logs, :retirement_reason, :text
    reversible do |direction|
      direction.up do
        execute <<~SQL
          UPDATE webhook_logs
          SET delivery_state = 'retired', retired_at = processed_at,
              retirement_reason = error_message
          WHERE processed_at IS NOT NULL
            AND error_message LIKE 'Retired by operator request %'
        SQL
      end
    end
    add_index :webhook_logs, [ :delivery_state, :next_attempt_at ], where: "processed_at IS NULL", name: "index_webhook_logs_on_pending_delivery"
  end
end
