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

    Redirect = Class.new(Generic)

    # Add HTML to a successful response
    class Success < Generic
      attr_reader :response, :html

      private

      def initialize(url, response, html)
        @response = response
        @html = html
        super url
      end
    end

    # We found a canonical URL!
    class CanonicalFound < Generic
      attr_reader :response

      private

      def initialize(url, response)
        @response = response
        super url
      end
    end

    # It barfed
    class Failure
      attr_reader :failure_class, :message

      private

      def initialize(failure_class, message)
        @failure_class = failure_class
        @message = message
      end
    end
  end
end
