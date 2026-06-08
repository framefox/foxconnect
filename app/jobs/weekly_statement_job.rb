class WeeklyStatementJob < ApplicationJob
  queue_as :default

  def perform(reference_date: nil)
    WeeklyStatementService.new(reference_date: reference_date).call
  end
end
