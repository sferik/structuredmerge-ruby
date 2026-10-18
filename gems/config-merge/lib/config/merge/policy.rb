# frozen_string_literal: true

require "yaml"
require_relative "normalizer_registry"

module Config
  module Merge
    # Immutable policy for resolving conflicts in a line-oriented flag file.
    class Policy
      Rule = Struct.new(:cardinality, :on_conflict, :normalizer, keyword_init: true) do
        def initialize(cardinality:, on_conflict:, normalizer:)
          super(cardinality: cardinality.to_sym, on_conflict: on_conflict.to_sym, normalizer: normalizer.to_sym)
          freeze
        end
      end

      CARDINALITIES = %i[single repeatable].freeze
      CONFLICT_ACTIONS = %i[conflict ours theirs base union].freeze
      ROOT_KEYS = %w[name format defaults flags].freeze
      RULE_KEYS = %w[cardinality on_conflict normalizer].freeze

      attr_reader :name, :format, :defaults, :flags

      def self.load(path)
        raise ArgumentError, "Policy file not found: #{path}" unless File.file?(path)

        new(YAML.safe_load_file(path, permitted_classes: [], aliases: false))
      end

      def initialize(config)
        normalized = validate_config(config)
        @name = normalized["name"]&.to_s
        @format = normalized["format"]&.to_s || "flag_file"
        validate_format!
        @defaults = build_rule(normalized["defaults"] || {}, default: true)
        @flags = parse_flags(normalized["flags"] || {}).freeze
        freeze
      end

      def rule_for(flag)
        flags.fetch(normalize_flag(flag), defaults)
      end

      private

      def validate_config(config)
        normalized = stringify_keys(config)
        reject_unknown_keys!(normalized, ROOT_KEYS, "policy")
        normalized
      end

      def validate_format!
        return if format == "flag_file"

        raise ArgumentError, "unsupported policy format: #{format}"
      end

      def parse_flags(config)
        raise ArgumentError, "flags must be a mapping" unless config.is_a?(Hash)

        config.to_h do |flag, values|
          raise ArgumentError, "flag policy for #{flag.inspect} must be a mapping" unless values.is_a?(Hash)

          [normalize_flag(flag), build_rule(stringify_keys(values), default: false)]
        end
      end

      def build_rule(values, default:)
        values = stringify_keys(values)
        reject_unknown_keys!(values, RULE_KEYS, "rule")
        cardinality = rule_value(values, "cardinality", default ? "repeatable" : "single").to_sym
        on_conflict = rule_value(values, "on_conflict", "conflict").to_sym
        normalizer = rule_value(values, "normalizer", "identity").to_sym
        validate_rule!(cardinality, on_conflict, normalizer)
        Rule.new(cardinality: cardinality, on_conflict: on_conflict, normalizer: normalizer)
      end

      def rule_value(values, key, fallback)
        values.fetch(key, fallback)
      end

      def validate_rule!(cardinality, on_conflict, normalizer)
        raise ArgumentError, "invalid cardinality: #{cardinality}" unless CARDINALITIES.include?(cardinality)
        raise ArgumentError, "invalid conflict action: #{on_conflict}" unless CONFLICT_ACTIONS.include?(on_conflict)
        if cardinality == :single && on_conflict == :union
          raise ArgumentError, "single-valued flags cannot use the union conflict action"
        end
        raise ArgumentError, "unknown normalizer: #{normalizer}" unless NormalizerRegistry.registered?(normalizer)
      end

      def reject_unknown_keys!(hash, allowed, context)
        unknown = hash.keys - allowed
        raise ArgumentError, "unknown #{context} key(s): #{unknown.join(", ")}" unless unknown.empty?
      end

      def stringify_keys(hash)
        raise ArgumentError, "expected a mapping" unless hash.is_a?(Hash)

        hash.each_with_object({}) { |(key, value), result| result[key.to_s] = value }
      end

      def normalize_flag(flag)
        value = flag.to_s
        raise ArgumentError, "flag names must not be empty" if value.empty?

        value
      end
    end
  end
end
