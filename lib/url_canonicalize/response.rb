# frozen_string_literal: true

module URLCanonicalize
  # The response from an HTTP request
  module Response
    class Generic
      attr_reader :url

      private

      def initialize(url)
        @url = url
      end
    end

    # A redirect to another URL
    class Redirect < Generic; end

    # Add HTML to a successful response
    class Success < Generic
      attr_reader :response, :html

      def xml
        @xml ||= Nokogiri::XML response.body
      end

      private

      def initialize(url, response, html)
        @response = response
        @html = html
        super(url)
      end
    end

    # We found a canonical URL!
    class CanonicalFound < Generic
      attr_reader :response

      private

      def initialize(url, response)
        @response = response
        super(url)
      end
    end

    # It barfed. When the failure came from a rescued exception, `error` holds
    # the original exception so callers can see the real cause
    class Failure
      attr_reader :failure_class, :message, :error

      private

      def initialize(failure_class, message, error = nil)
        @failure_class = failure_class
        @message = message
        @error = error
      end
    end
  end
end
