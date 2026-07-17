# frozen_string_literal: true

module URI
  # URI having the HTTP protocol
  class HTTP
    def canonicalize(**options)
      new_url = URLCanonicalize.canonicalize(to_s, **options)
      ::URI.parse(new_url)
    end
  end
end
