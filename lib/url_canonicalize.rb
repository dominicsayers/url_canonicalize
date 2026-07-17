# frozen_string_literal: true

require 'uri'
require 'addressable/uri'
require 'net/http'
require 'nokogiri'
require 'timeout'

autoload :OpenSSL, 'openssl'

# Core methods
module URLCanonicalize
  autoload :BoundedBody, 'url_canonicalize/bounded_body'
  autoload :Destination, 'url_canonicalize/destination'
  autoload :Exception, 'url_canonicalize/exception'
  autoload :HTTP, 'url_canonicalize/http'
  autoload :LinkHeader, 'url_canonicalize/link_header'
  autoload :MediaType, 'url_canonicalize/media_type'
  autoload :Options, 'url_canonicalize/options'
  autoload :Request, 'url_canonicalize/request'
  autoload :Response, 'url_canonicalize/response'
  autoload :URI, 'url_canonicalize/uri'
  autoload :VERSION, 'url_canonicalize/version'

  class << self
    def canonicalize(url, **options)
      fetch(url, **options).url
    end

    def fetch(url, **options)
      URLCanonicalize::HTTP.new(url, **options).fetch
    end
  end
end

require 'monkey_patches/uri'
require 'monkey_patches/string'
require 'monkey_patches/addressable/uri'
