require 'uri'
require 'addressable/uri'
require 'net/http'
require 'nokogiri'

autoload :OpenSSL, 'openssl'

# Core methods
module URLCanonicalize
  autoload :Exception, 'url_canonicalize/exception'
  autoload :HTTP, 'url_canonicalize/http'
  autoload :Request, 'url_canonicalize/request'
  autoload :Response, 'url_canonicalize/response'
  autoload :URI, 'url_canonicalize/uri'
  autoload :VERSION, 'url_canonicalize/version'

  class << self
    def canonicalize(url)
      fetch(url).url
    end

    def fetch(url)
      URLCanonicalize::HTTP.new(url).fetch
    end
  end
end

require 'monkey_patches/uri'
require 'monkey_patches/string'
require 'monkey_patches/addressable/uri'
require 'English' # Needed for $LAST_MATCH_INFO
