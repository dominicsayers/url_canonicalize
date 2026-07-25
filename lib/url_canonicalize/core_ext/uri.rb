# frozen_string_literal: true

require 'uri'

module URI
  # URI having the HTTP protocol
  class HTTP
    def canonicalize(**)
      new_url = URLCanonicalize.canonicalize(to_s, **)
      ::URI.parse(new_url)
    end
  end
end
