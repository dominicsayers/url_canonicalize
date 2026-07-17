# frozen_string_literal: true

require 'ipaddr'
require 'socket'

module URLCanonicalize
  # Resolves a URI to an address that is permitted by the fetch security policy
  class Destination
    FORBIDDEN_IPV4_RANGES = %w[
      0.0.0.0/8
      10.0.0.0/8
      100.64.0.0/10
      127.0.0.0/8
      169.254.0.0/16
      172.16.0.0/12
      192.0.0.0/24
      192.0.2.0/24
      192.88.99.0/24
      192.168.0.0/16
      198.18.0.0/15
      198.51.100.0/24
      203.0.113.0/24
      224.0.0.0/4
      240.0.0.0/4
    ].map { |range| IPAddr.new(range) }.freeze

    # Fail closed: only prefixes in IANA's IPv6 Global Unicast Address Space registry are accepted.
    ALLOCATED_IPV6_RANGES = %w[
      2001:200::/23
      2001:400::/23
      2001:600::/23
      2001:800::/22
      2001:c00::/23
      2001:e00::/23
      2001:1200::/23
      2001:1400::/22
      2001:1800::/23
      2001:1a00::/23
      2001:1c00::/22
      2001:2000::/19
      2001:4000::/23
      2001:4200::/23
      2001:4400::/23
      2001:4600::/23
      2001:4800::/23
      2001:4a00::/23
      2001:4c00::/23
      2001:5000::/20
      2001:8000::/19
      2001:a000::/20
      2001:b000::/20
      2003::/18
      2400::/12
      2410::/12
      2600::/12
      2610::/23
      2620::/23
      2630::/12
      2800::/12
      2a00::/12
      2a10::/12
      2c00::/12
    ].map { |range| IPAddr.new(range) }.freeze

    FORBIDDEN_IPV6_RANGES = %w[
      2001::/23
      2001:db8::/32
      2002::/16
    ].map { |range| IPAddr.new(range) }.freeze

    class << self
      def resolve(uri, options)
        validate!(uri, options)
        addresses = resolve_addresses(uri)
        validate_addresses!(uri, addresses, options)
        addresses.first
      end

      def validate!(uri, options)
        raise URLCanonicalize::Exception::Security, 'URLs containing userinfo are not allowed' if uri.userinfo
        return if options[:allowed_ports].include?(uri.port)

        raise URLCanonicalize::Exception::Security, "Port #{uri.port} is not allowed"
      end

      private

      def resolve_addresses(uri)
        addresses = Addrinfo.getaddrinfo(uri.host, uri.port, nil, Socket::SOCK_STREAM)
        addresses = addresses.map(&:ip_address).uniq
        raise SocketError, "No addresses found for #{uri.host}" if addresses.empty?

        addresses
      end

      def validate_addresses!(uri, addresses, options)
        return if options[:allow_private_networks]

        addresses.each do |address|
          next if public_address?(address)

          raise URLCanonicalize::Exception::Security,
                "Address #{address} for #{uri.host} is not publicly routable"
        end
      end

      def public_address?(value)
        address = IPAddr.new(value)
        address = address.native if address.ipv4_mapped?

        if address.ipv4?
          FORBIDDEN_IPV4_RANGES.none? { |range| range.include?(address) }
        else
          ALLOCATED_IPV6_RANGES.any? { |range| range.include?(address) } &&
            FORBIDDEN_IPV6_RANGES.none? { |range| range.include?(address) }
        end
      end
    end
  end
end
