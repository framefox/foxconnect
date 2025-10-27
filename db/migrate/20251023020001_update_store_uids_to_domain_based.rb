class UpdateStoreUidsToDomainBased < ActiveRecord::Migration[8.0]
  def up
    Store.find_each do |store|
      # Determine base UID from platform-specific domain
      base_uid = case store.platform
      when "shopify"
        # Extract subdomain (part before .myshopify.com)
        store.shopify_domain&.sub(/\.myshopify\.com$/, '')
      when "wix"
        store.wix_site_id
      when "squarespace"
        # Extract subdomain if it's a squarespace domain
        store.squarespace_domain&.sub(/\.squarespace\.com$/, '')
      else
        # Fallback to random alphanumeric for unknown platforms
        SecureRandom.alphanumeric(8).downcase
      end

      # Handle nil base_uid (shouldn't happen but be defensive)
      if base_uid.nil?
        base_uid = SecureRandom.alphanumeric(8).downcase
      end

      # Check for conflicts and add suffix if needed
      candidate_uid = base_uid
      suffix = 1

      while Store.where.not(id: store.id).exists?(uid: candidate_uid)
        candidate_uid = "#{base_uid}-#{suffix}"
        suffix += 1
      end

      store.update_column(:uid, candidate_uid)
    end
  end

  def down
    # Generate random alphanumeric UIDs for all stores (previous format)
    Store.find_each do |store|
      loop do
        uid = SecureRandom.alphanumeric(8).downcase
        unless Store.where.not(id: store.id).exists?(uid: uid)
          store.update_column(:uid, uid)
          break
        end
      end
    end
  end
end
