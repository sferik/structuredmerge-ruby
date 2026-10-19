# frozen_string_literal: true

require 'token/resolver'

module Ast
  module Template
    # Token application policy: normalize replacements, resolve with
    # on-missing keep, then police tokens that survive in the consumer's
    # namespace. Token mechanics (parsing, grammar) live in token-resolver;
    # this module is the contract surface defined by
    # structuredmerge/spec slice-1041 and its conformance fixtures.
    module TokenApplication
      # Raised when resolved output still contains tokens in the consumer's
      # namespace. Carries the sorted, deduplicated canonical full keys so
      # consumers can re-raise with their own branded message.
      class UnresolvedTokensError < ArgumentError
        # @return [Array<String>] canonical full token keys, sorted
        attr_reader :tokens

        def initialize(tokens)
          @tokens = tokens
          super("unresolved template tokens: #{tokens.map { |token| "{#{token}}" }.join(', ')}")
        end
      end

      module_function

      # Resolve tokens in content, then (when scanning) raise if any token in
      # the consumer's namespace survived. Missing replacements are kept
      # verbatim — in canonical form, so the scan sees canonical keys.
      #
      # @param content [String] template content
      # @param replacements [Hash] token canonical key => value (keys and
      #   values are stringified before resolution)
      # @param config [Token::Resolver::Config] token structure config
      # @param namespace [String] first-segment namespace the consumer owns
      # @param scan_unresolved [Boolean] when false, unresolved tokens pass
      # @return [String] resolved content
      # @raise [UnresolvedTokensError] unresolved namespaced tokens remain
      def apply_tokens(content, replacements, config:, namespace:, scan_unresolved: true)
        document = Token::Resolver::Document.new(content.to_s, config: config)
        resolved = Token::Resolver::Resolve.new(on_missing: :keep).resolve(document,
                                                                           stringify_replacements(replacements))
        return resolved unless scan_unresolved

        unresolved = unresolved_namespaced_tokens(resolved, config: config, namespace: namespace)
        return resolved if unresolved.empty?

        raise UnresolvedTokensError, unresolved
      end

      # Sorted, deduplicated canonical keys of tokens in content whose first
      # segment equals namespace.
      #
      # @return [Array<String>]
      def unresolved_namespaced_tokens(content, config:, namespace:)
        Token::Resolver::Document.new(content.to_s, config: config)
                                 .token_keys
                                 .select do |key|
          key.split(
            config.separators.first, 2
          ).first == namespace
        end
                                                        .uniq
                                                        .sort
      end

      # Normalize replacements for the resolver: string keys and values.
      #
      # @return [Hash{String => String}]
      def stringify_replacements(replacements)
        replacements.to_h.transform_keys(&:to_s).transform_values(&:to_s)
      end
    end
  end
end
