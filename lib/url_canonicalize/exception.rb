# frozen_string_literal: true
# Core methods
module URLCanonicalize
  # Local exception classes to make handling exceptions easier
  class Exception < RuntimeError
    Failure = Class.new(self)
    Redirect = Class.new(self)
    Request = Class.new(self)
    URI = Class.new(self)
  end
end
