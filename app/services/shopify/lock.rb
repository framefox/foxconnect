module Shopify
  module Lock
    # Session locks serialize deliveries without wrapping remote API calls/token
    # rotation in a DB transaction that might later roll back the rotated token.
    NAMESPACES = { delivery: 74001, store: 74002, fulfillment: 74003, inventory: 74004 }.freeze

    def self.try_with(type, id)
      namespace = NAMESPACES.fetch(type)
      key = Integer(id)
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        acquired = connection.select_value("SELECT pg_try_advisory_lock(#{namespace}, #{key})")
        return unless acquired
        begin
          yield
        ensure
          connection.execute("SELECT pg_advisory_unlock(#{namespace}, #{key})")
        end
      end
    end

    def self.with(type, id)
      namespace = NAMESPACES.fetch(type)
      key = Integer(id)
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SELECT pg_advisory_lock(#{namespace}, #{key})")
        begin
          yield
        ensure
          connection.execute("SELECT pg_advisory_unlock(#{namespace}, #{key})")
        end
      end
    end
  end
end
