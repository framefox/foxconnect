# Current attributes for the current request context
# This uses ActiveSupport::CurrentAttributes to provide thread-safe, request-scoped attributes
# https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :subdomain, :request_id, :user_agent

  # Returns the current user
  def self.user
    RequestStore[:current_user]
  end

  # Sets the current user
  def self.user=(user)
    RequestStore[:current_user] = user
  end

  # Resets all attributes after each request
  resets do
    RequestStore.clear!
  end
end

