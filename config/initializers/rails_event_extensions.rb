module RailsEventExtensions
  def notify_with_tags(name, payload = {}, tags: {}, **options)
    tagged(tags) do
      notify(name, payload, **options)
    end
  end
end

Rails.event.extend(RailsEventExtensions)
