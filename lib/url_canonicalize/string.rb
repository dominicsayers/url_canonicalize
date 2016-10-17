module URLCanonicalize
  # Methods for URI classes
  module String
    def canonicalize
      URLCanonicalize.canonicalize(to_s)
    end
  end
end
