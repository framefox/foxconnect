require "csv"

namespace :orders do
  desc "Import manual orders from CSV file"
  task import_csv: :environment do
    # Hardcoded path to CSV in root
    csv_path = Rails.root.join("leden1.csv").to_s

    unless File.exist?(csv_path)
      puts "Error: CSV file not found at #{csv_path}"
      exit 1
    end

    # Hardcoded user
    user = User.find_by(email: "operations@ledendesign.com")

    unless user
      puts "Error: User operations@ledendesign.com not found in database."
      exit 1
    end

    puts "Importing orders for user: #{user.email}"
    puts "Reading CSV from: #{csv_path}"
    puts ""

    successful_imports = 0
    failed_imports = []

    CSV.foreach(csv_path, headers: true) do |row|
      next if row["Order"].blank? # Skip rows without order number

      order_name = row["Order"].to_s.strip
      customer_name = row["Customer Name"].to_s.strip
      delivery_address = row["Delivery Address"].to_s.strip
      phone = row["Phone No"].to_s.strip

      # Skip if essential data is missing
      if order_name.blank? || customer_name.blank? || delivery_address.blank?
        puts "⚠️  Skipping row - missing essential data"
        next
      end

      begin
        # Check if order already exists
        if Order.exists?(external_id: order_name, user_id: user.id)
          puts "⚠️  Order #{order_name} already exists - skipping"
          next
        end

        # Create the order
        order = Order.new(
          user_id: user.id,
          external_id: order_name,
          name: order_name,
          currency: "NZD",
          country_code: "NZ",
          # Initialize all required money fields to 0
          subtotal_price_cents: 0,
          total_discounts_cents: 0,
          total_shipping_cents: 0,
          total_tax_cents: 0,
          total_price_cents: 0,
          production_subtotal_cents: 0,
          production_shipping_cents: 0,
          production_total_cents: 0,
          aasm_state: "draft"
        )

        if order.save
          # Parse customer name (split on first space)
          name_parts = customer_name.split(" ", 2)
          first_name = name_parts[0] || ""
          last_name = name_parts[1] || ""

          # Parse delivery address
          # Format: "Street Address, City, Postcode" or variations
          address_parts = delivery_address.split(",").map(&:strip)

          address1 = nil
          city = nil
          postal_code = nil

          if address_parts.length >= 3
            # Standard format: address, city, postcode
            address1 = address_parts[0..-3].join(", ")
            city = address_parts[-2]
            postal_code = address_parts[-1]
          elsif address_parts.length == 2
            # Two parts: address, city or city, postcode
            address1 = address_parts[0]
            city = address_parts[1]
          elsif address_parts.length == 1
            # Only one part - use as address
            address1 = address_parts[0]
          end

          # Create shipping address
          shipping_address = ShippingAddress.new(
            order_id: order.id,
            first_name: first_name,
            last_name: last_name,
            name: customer_name,
            phone: phone,
            address1: address1,
            city: city,
            postal_code: postal_code,
            country: "New Zealand",
            country_code: "NZ"
          )

          if shipping_address.save
            successful_imports += 1
            puts "✅ Created order #{order_name} for #{customer_name}"
          else
            failed_imports << { order: order_name, errors: shipping_address.errors.full_messages }
            order.destroy # Rollback order if shipping address fails
            puts "❌ Failed to create shipping address for #{order_name}: #{shipping_address.errors.full_messages.join(', ')}"
          end
        else
          failed_imports << { order: order_name, errors: order.errors.full_messages }
          puts "❌ Failed to create order #{order_name}: #{order.errors.full_messages.join(', ')}"
        end
      rescue => e
        failed_imports << { order: order_name, errors: [ e.message ] }
        puts "❌ Error processing #{order_name}: #{e.message}"
      end
    end

    puts ""
    puts "=" * 50
    puts "Import Summary"
    puts "=" * 50
    puts "✅ Successfully imported: #{successful_imports} orders"
    puts "❌ Failed: #{failed_imports.length} orders"

    if failed_imports.any?
      puts ""
      puts "Failed orders:"
      failed_imports.each do |failure|
        puts "  - #{failure[:order]}: #{failure[:errors].join(', ')}"
      end
    end
  end
end
