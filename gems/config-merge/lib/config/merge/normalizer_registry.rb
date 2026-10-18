# frozen_string_literal: true

require "monitor"

module Config
  module Merge
    # Thread-safe registry of named value normalizers used for semantic comparison.
    # Normalizers change comparison values only; rendering keeps the original text.
    class NormalizerRegistry
      class UnknownNormalizerError < ArgumentError; end

      @monitor = Monitor.new
      @normalizers = {
        identity: ->(value) { value },
        strip: ->(value) { value&.strip },
        downcase: ->(value) { value&.downcase }
      }

      class << self
        def register(name, callable = nil, replace: false, &block)
          normalizer = callable || block
          raise ArgumentError, "normalizer must respond to #call" unless normalizer.respond_to?(:call)

          key = normalize_name(name)
          @monitor.synchronize do
            raise ArgumentError, "Normalizer already registered: #{key}" if @normalizers.key?(key) && !replace

            @normalizers[key] = normalizer
          end
          key
        end

        def normalize(name, value)
          key = normalize_name(name)
          normalizer = @monitor.synchronize { @normalizers[key] }
          raise UnknownNormalizerError, "Unknown normalizer: #{key}" unless normalizer

          normalizer.call(value)
        end

        def registered?(name)
          @monitor.synchronize { @normalizers.key?(normalize_name(name)) }
        end

        def names
          @monitor.synchronize { @normalizers.keys.sort.freeze }
        end

        private

        def normalize_name(name)
          name.to_s.downcase.tr("-", "_").to_sym
        end
      end
    end
  end
end
