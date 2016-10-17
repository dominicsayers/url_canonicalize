# Core methods
module URLCanonicalize
  # Local exception classes to make handling exceptions easier
  class Exception < RuntimeError
    URI = Class.new(self)
    Redirect = Class.new(self)
  end
end
