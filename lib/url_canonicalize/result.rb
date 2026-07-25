# frozen_string_literal: true

module URLCanonicalize
  # The outcome of one canonicalization: the canonical URL, the response
  # that confirmed it, and the chain of hops that led there. Immutable
  class Result
    # One step in the request chain: the URL that was requested and how it
    # was discovered (:initial, :redirect or :canonical_link)
    Hop = Struct.new(:url, :via, keyword_init: true)

    attr_reader :url, :response, :html, :chain, :source

    def xml
      Nokogiri::XML(response.body)
    end

    private

    def initialize(url:, response:, html:, chain:, source:)
      @url = url
      @response = response
      @html = html
      @chain = chain.map(&:freeze).freeze
      @source = source
      freeze
    end
  end
end
