module StatementDeliverySchedule
  TIME_ZONE = "Auckland"
  DELIVERY_WDAY = 1
  DELIVERY_HOUR = 8
  DELIVERY_MINUTE = 0
  PAYMENT_TERMS_DAYS = 7

  module_function

  def next_delivery_after(time)
    local_time = time.in_time_zone(TIME_ZONE)
    local_date = local_time.to_date
    days_until_delivery = (DELIVERY_WDAY - local_date.wday) % 7
    delivery_date = local_date + days_until_delivery
    delivery_at = local_delivery_time(delivery_date)

    delivery_at <= local_time ? delivery_at + 7.days : delivery_at
  end

  def due_date_for(time)
    (next_delivery_after(time) + PAYMENT_TERMS_DAYS.days).to_date
  end

  def local_delivery_time(date)
    zone.local(date.year, date.month, date.day, DELIVERY_HOUR, DELIVERY_MINUTE)
  end

  def zone
    Time.find_zone!(TIME_ZONE)
  end
end
