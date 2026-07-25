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
  autoload :Client, 'url_canonicalize/client'
  autoload :Destination, 'url_canonicalize/destination'
  autoload :Exception, 'url_canonicalize/exception'
  autoload :HTTP, 'url_canonicalize/http'
  autoload :LinkHeader, 'url_canonicalize/link_header'
  autoload :MediaType, 'url_canonicalize/media_type'
  autoload :Options, 'url_canonicalize/options'
  autoload :Request, 'url_canonicalize/request'
  autoload :Response, 'url_canonicalize/response'
  autoload :Result, 'url_canonicalize/result'
  autoload :Transport, 'url_canonicalize/transport'
  autoload :URI, 'url_canonicalize/uri'
  autoload :VERSION, 'url_canonicalize/version'

  class << self
    def canonicalize(url, **)
      Client.new(**).canonicalize(url)
    end

    def fetch(url, **)
      Client.new(**).fetch(url)
    end
  end
end
