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

    class CanonicalFound < Generic
      attr_reader :response

      private

      def initialize(url, response)
        @url = url
        @response = response
      end
    end

    # It barfed
    class Failure < Generic
    end
  end
end
