# frozen_string_literal: true

module URLCanonicalize
  # Parses HTTP Link header fields (RFC 8288) far enough to find the target of
  # the first link whose rel tokens include "canonical"
  module LinkHeader
    LINK_VALUE = /<([^>]*)>((?:\s*;\s*[\w!#$%&'*+.^`|~-]+\s*=\s*(?:"[^"]*"|[^",;]+))*)/
    REL_PARAM = /;\s*rel\s*=\s*(?:"([^"]*)"|([^",;\s]+))/i
    CANONICAL = 'canonical'

    extend self

    def canonical(response)
      fields = response.get_fields('link')
      return unless fields

      fields.each do |field|
        field.scan(LINK_VALUE) do |target, params|
          return target if canonical?(params)
        end
      end

      nil
    end

    def canonical?(params)
      match = REL_PARAM.match(params)
      return false unless match

      rel = match[1] || match[2]
      rel.split.any? { |token| token.casecmp?(CANONICAL) }
    end
  end
end
