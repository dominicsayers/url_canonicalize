# frozen_string_literal: true

module Addressable
  # Patch for Addressable's URI class
  class URI
    def self.canonicalize(uri, **options)
      url = parse(uri).to_s # uri can be anything Addressable::URI can handle
      canonical_url = URLCanonicalize.canonicalize(url, **options)
      parse(canonical_url)
    end
  end
end
