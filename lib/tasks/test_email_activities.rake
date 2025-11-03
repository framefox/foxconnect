namespace :test do
  desc "Test email activity logging by sending a draft imported email"
  task email_activities: :environment do
    order = Order.joins(store: :user).where.not(users: { email: nil }).first
    
    if order.nil?
      puts "No orders found with a user email address"
      exit
    end
    
    puts "Testing email activity logging for order: #{order.display_name}"
    puts "User email: #{order.store.user.email}"
    puts "Sending draft imported email..."
    
    # Send the email (which will log the activity)
    OrderMailer.with(order_id: order.id).draft_imported.deliver_now
    
    puts "\nEmail sent! Checking activities..."
    
    # Check the last activity
    last_activity = order.order_activities.recent.first
    
    if last_activity&.email_draft_imported?
      puts "✅ Success! Email activity logged:"
      puts "   Title: #{last_activity.title}"
      puts "   Description: #{last_activity.description}"
      puts "   Metadata: #{last_activity.metadata.inspect}"
      puts "\nOpen http://localhost:3000/letter_opener to view the email"
    else
      puts "❌ Failed to log email activity"
      puts "Last activity: #{last_activity&.activity_type}"
    end
  end
  
  desc "Test fulfillment notification email activity"
  task fulfillment_email: :environment do
    fulfillment = Fulfillment.joins(order: { store: :user }).where.not(users: { email: nil }).first
    
    if fulfillment.nil?
      puts "No fulfillments found"
      exit
    end
    
    order = fulfillment.order
    
    puts "Testing fulfillment notification for order: #{order.display_name}"
    puts "User email: #{order.store.user.email}"
    puts "Sending fulfillment notification email..."
    
    # Send the email (which will log the activity)
    OrderMailer.with(order_id: order.id, fulfillment_id: fulfillment.id).fulfillment_notification.deliver_now
    
    puts "\nEmail sent! Checking activities..."
    
    # Check the last activity
    last_activity = order.order_activities.recent.first
    
    if last_activity&.email_fulfillment_notification?
      puts "✅ Success! Email activity logged:"
      puts "   Title: #{last_activity.title}"
      puts "   Description: #{last_activity.description}"
      puts "   Metadata: #{last_activity.metadata.inspect}"
      puts "\nOpen http://localhost:3000/letter_opener to view the email"
    else
      puts "❌ Failed to log email activity"
      puts "Last activity: #{last_activity&.activity_type}"
    end
  end
end

