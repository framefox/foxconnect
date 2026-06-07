class AddSubscribedToNotificationsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :subscribed_to_notifications, :boolean, default: true, null: false
  end
end
