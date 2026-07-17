# frozen_string_literal: true

# Patch for Ruby's String class
class String
  def canonicalize(**options)
    URLCanonicalize.canonicalize(self, **options)
  end
end
