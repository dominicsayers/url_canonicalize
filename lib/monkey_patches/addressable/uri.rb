module Addressable
  # Patch for Addressable's URI class
  class URI
    extend URLCanonicalize::Addressable::URI
  end
end
