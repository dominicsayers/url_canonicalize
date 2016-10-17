module Addressable
  # Patch for Addressable's URI class
  class URI
    def self.canonicalize(uri)
      url = parse(uri).to_s # uri can be anything Addressable::URI can handle
      canonical_url = URLCanonicalize.canonicalize(url)
      parse(canonical_url)
    end
  end
end
