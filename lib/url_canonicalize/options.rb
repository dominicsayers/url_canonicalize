# frozen_string_literal: true

module URLCanonicalize
  # Validated configuration for one canonicalization operation
  class Options
    DEFAULTS = {
      allow_private_networks: false,
      allowed_ports: [80, 443].freeze,
      headers: {
        'Accept-Language' => 'en-US,en;q=0.8',
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; WOW64) ' \
                        'AppleWebKit/537.36 (KHTML, like Gecko) ' \
                        'Chrome/51.0.2704.103 Safari/537.36'
      }.freeze,
      logger: nil,
      max_body_bytes: 1_048_576,
      total_timeout: 30,
      open_timeout: 8,
      read_timeout: 15,
      write_timeout: 8,
      max_redirects: 10,
      transport: Transport.new
    }.freeze

    POSITIVE_NUMERIC_OPTIONS = %i[total_timeout open_timeout read_timeout write_timeout].freeze
    POSITIVE_INTEGER_OPTIONS = %i[max_body_bytes max_redirects].freeze

    def initialize(**values)
      validate_known_options!(values)

      @values = DEFAULTS.merge(values)
      validate!
      @values[:allowed_ports] = @values[:allowed_ports].dup.freeze
      @values[:headers] = @values[:headers].dup.freeze
      @values.freeze
      freeze
    end

    def [](key)
      @values.fetch(key)
    end

    def to_h
      @values.merge(allowed_ports: @values[:allowed_ports].dup, headers: @values[:headers].dup)
    end

    private

    def validate!
      validate_private_networks!
      validate_ports!
      validate_positive_values!
      validate_headers!
      validate_logger!
      validate_transport!
    end

    def validate_known_options!(values)
      unknown = values.keys - DEFAULTS.keys
      raise ArgumentError, "Unknown options: #{unknown.join(', ')}" unless unknown.empty?
    end

    def validate_private_networks!
      return if [true, false].include?(@values[:allow_private_networks])

      raise ArgumentError, 'allow_private_networks must be true or false'
    end

    def validate_ports!
      ports = @values[:allowed_ports]
      valid = ports.is_a?(Array) && !ports.empty? && ports.all? do |port|
        port.is_a?(Integer) && port.between?(1, 65_535)
      end
      return if valid

      raise ArgumentError, 'allowed_ports must contain only valid TCP ports'
    end

    def validate_positive_values!
      POSITIVE_NUMERIC_OPTIONS.each do |name|
        value = @values[name]
        raise ArgumentError, "#{name} must be positive" unless value.is_a?(Numeric) && value.positive?
      end

      POSITIVE_INTEGER_OPTIONS.each do |name|
        value = @values[name]
        raise ArgumentError, "#{name} must be positive" unless value.is_a?(Integer) && value.positive?
      end
    end

    def validate_headers!
      headers = @values[:headers]
      valid = headers.is_a?(Hash) && headers.all? { |key, value| key.is_a?(String) && value.is_a?(String) }
      return if valid

      raise ArgumentError, 'headers must be a Hash of String keys and String values'
    end

    def validate_logger!
      logger = @values[:logger]
      return if logger.nil? || logger.respond_to?(:debug)

      raise ArgumentError, 'logger must respond to debug'
    end

    def validate_transport!
      return if @values[:transport].respond_to?(:call)

      raise ArgumentError, 'transport must respond to call'
    end
  end
end
