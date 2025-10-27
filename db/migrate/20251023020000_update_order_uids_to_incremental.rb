class UpdateOrderUidsToIncremental < ActiveRecord::Migration[8.0]
  def up
    # Get all orders sorted by created_at to maintain order history
    orders = Order.order(:created_at).to_a
    
    # Update each order with incremental UIDs starting from 1001
    orders.each_with_index do |order, index|
      new_uid = (1001 + index).to_s
      order.update_column(:uid, new_uid)
    end
  end

  def down
    # Generate random alphanumeric UIDs for all orders (previous format)
    Order.find_each do |order|
      loop do
        uid = SecureRandom.alphanumeric(10).downcase
        unless Order.where.not(id: order.id).exists?(uid: uid)
          order.update_column(:uid, uid)
          break
        end
      end
    end
  end
end

