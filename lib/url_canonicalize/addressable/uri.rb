module URLCanonicalize
  module Addressable
    # Methods for Addressable::URI classes
    module URI
      def canonicalize(uri)
        url = parse(uri).to_s # uri can be anything Addressable::URI can handle
        canonical_url = URLCanonicalize.canonicalize(url)
        parse(canonical_url)
      end
    end
  end
end
