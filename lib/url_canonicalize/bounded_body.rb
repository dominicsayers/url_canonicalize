# frozen_string_literal: true

module URLCanonicalize
  # String-compatible response buffer that enforces a maximum byte size
  class BoundedBody < String
    def initialize(max_bytes)
      @max_bytes = max_bytes
      super()
    end

    def <<(chunk)
      raise URLCanonicalize::Exception::ResponseTooLarge, error_message if bytesize + chunk.bytesize > @max_bytes

      super
    end

    private

    def error_message
      "Response body exceeds #{@max_bytes} bytes"
    end
  end
end
