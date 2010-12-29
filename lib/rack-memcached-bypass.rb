require 'rack'
require 'dalli'
#require 'memcache-client'

module Rack
  class MemcachedBypass
    def initialize(app, options = {})
      @app, @options = app, options
      @options[:servers] ||= ['localhost:11211']
      @options[:prefix] ||= 'rack-memcachedbypass'
      @options[:ttl] ||= nil
      @cache = Dalli::Client.new(@options[:servers])
#      @cache = MemCache.new(@options[:servers])
    end

    def call(env)
      @req = Rack::Request.new(env)

      status, headers, response = @app.call(env)

      if should_store?(response, status)
        store response
      end
      
      [status, headers, response]
    end

    def should_store?(response, status)
      return false if status >= 300
      return false unless "GET" == response.request.request_method
      true
    end

    def store(response, body = "")
      key = "#{@options[:prefix]}:#{response.request.path_info}?#{response.request.query_string}"
      response.each{ |s| body << s.to_s }
      puts key
      @cache.set(key, "#{body} FROM CACHE", @options[:ttl], {:raw => true}) # marshal flag must be false to avoid corruption
    end
  end
end
