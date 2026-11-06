module RmagickTidy
  # Rack middleware that runs each request inside a scope:
  #
  #   use RmagickTidy::Middleware
  #
  # Only the Rack interface is used; rack itself is not required.
  #
  # The scope is not block-based: it stays open until the server closes the
  # response body, so a body that produces images lazily while it is
  # iterated (a streaming body, an Enumerator) still runs inside it and can
  # use images created by the app. An Array body is already complete, so its
  # scope ends as soon as the app returns.
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      stack = Registry.stack
      scope = Registry.push
      returned = false
      begin
        status, headers, body = @app.call(env)
        returned = true
      ensure
        Registry.pop_and_destroy(scope, from: stack) unless returned
      end

      if body.is_a?(Array)
        Registry.pop_and_destroy(scope, from: stack)
        return [status, headers, body]
      end

      [status, headers, BodyProxy.new(body) { Registry.pop_and_destroy(scope, from: stack) }]
    end

    # Wraps a response body and calls the given block once, after the body
    # is closed. Like Rack::BodyProxy, it forwards everything else to the
    # body, except to_ary / to_str, so that servers iterate it with each and
    # then call close instead of treating it as an Array or a String. each is
    # forwarded too rather than defined here, so a Rack 3 streaming body
    # (one that only responds to call) is not mistaken for an enumerable one.
    class BodyProxy
      def initialize(body, &on_close)
        @body = body
        @on_close = on_close
        @closed = false
      end

      def close
        return if @closed

        @closed = true
        begin
          @body.close if @body.respond_to?(:close)
        ensure
          @on_close.call
        end
      end

      def closed?
        @closed
      end

      def respond_to_missing?(name, include_all = false)
        return false if %i[to_ary to_str].include?(name)

        @body.respond_to?(name, include_all) || super
      end

      def method_missing(name, ...)
        if respond_to_missing?(name, false)
          @body.__send__(name, ...)
        else
          super
        end
      end
    end
  end
end
