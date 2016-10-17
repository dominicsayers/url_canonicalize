module URLCanonicalize
  # Methods for URI classes
  module URI
    def canonicalize
      new_url = URLCanonicalize.canonicalize(to_s)
      URI(new_url)
    end
  end
end
