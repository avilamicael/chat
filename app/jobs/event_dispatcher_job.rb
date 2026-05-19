class EventDispatcherJob < ApplicationJob
  queue_as :critical

  def perform(event_name, timestamp, data)
    Current.automation_depth = 0
    Rails.configuration.dispatcher.async_dispatcher.publish_event(event_name, timestamp, data)
  ensure
    Current.reset
  end
end
