ActiveSupport.on_load(:action_mailer) do
  register_interceptor(NotificationSubscriptionInterceptor)
end
