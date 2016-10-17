# Patch for Ruby's String class
class String
  def canonicalize
    URLCanonicalize.canonicalize(to_s)
  end
end
