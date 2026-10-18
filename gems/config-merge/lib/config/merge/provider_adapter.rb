# frozen_string_literal: true

module Config
  module Merge
    # Reuses an ast-merge provider for formats with an existing structural parser.
    #
    # The provider result is returned unchanged, including diagnostics,
    # verification details, and source-preserving output.
    class ProviderAdapter
      def initialize(family:, dialect: nil, backend: nil, profile_id: nil, provider_id: nil)
        @selectors = {
          family: family,
          dialect: dialect,
          backend: backend,
          profile_id: profile_id,
          provider_id: provider_id
        }.compact.freeze
      end

      # Dispatches a base-aware structural merge to the selected provider.
      #
      # @param base [String] common ancestor source
      # @param ours [String] current or destination source
      # @param theirs [String] incoming source
      # @param metadata [Hash, nil] provider-specific request metadata
      # @return [Hash] validated ast-merge provider result
      def merge3(base:, ours:, theirs:, metadata: nil)
        request = @selectors.merge(
          base_source: base,
          ours_source: ours,
          theirs_source: theirs
        )
        request[:metadata] = metadata if metadata

        Ast::Merge.dispatch_provider(:merge3, request)
      end
    end
  end
end
