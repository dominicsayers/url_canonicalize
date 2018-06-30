# frozen_string_literal: true

# Patch for Ruby's String class
class String
  def canonicalize
    URLCanonicalize.canonicalize(self)
  end
end
