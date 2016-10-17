# Patch for Ruby's String class
class String
  include URLCanonicalize::String
end
