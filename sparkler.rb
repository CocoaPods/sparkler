class Sparkler
  def initialize
    @feeds = {}
    @properties = {}
  end

  def call(env)
    request = Rack::Request.new(env)

    if request.path_info =~ %r(^/feed/([\w\-\.]+)$)
      feed_name = $1
      @feeds[feed_name] = Feed.find_by_name(feed_name) unless @feeds.has_key?(feed_name)
      feed = @feeds[feed_name]

      if feed
        if (userAgent = env["HTTP_USER_AGENT"]) && userAgent =~ %r(Sparkle/)
          now = Time.now
          save_params(feed, now, request.params)
          save_param(feed, now, 'appVersionShort', userAgent.split(' ').first.split('/').last)
        end

        feed.contents ? success(feed.contents) : not_found
      else
        not_found
      end
    else
      not_found
    end
  end

  def success(html)
    Rack::Response.new(html).to_a
  end

  def not_found
    Rack::Response.new("Not found :-(\n", 404).to_a
  end

  def save_params(feed, time, params)
    params = params.clone
    params.delete('appName')

    params.each do |property_name, value_name|
      save_param(feed, time, property_name, value_name)
    end
  end

  def save_param(feed, time, property_name, value_name)
    property = @properties[property_name] ||= Property.find_or_create_by(name: property_name)
    value = property.values.detect { |v| v.name == value_name } || property.values.create(name: value_name)

    statistic = Statistic.find_or_create_by(
      year: time.year,
      month: time.month,
      feed: feed,
      property: property,
      value: value
    )

    Statistic.update_counters(statistic.id, counter: 1)
  end
end
