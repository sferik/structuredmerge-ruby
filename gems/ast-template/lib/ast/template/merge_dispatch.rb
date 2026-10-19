# frozen_string_literal: true

module Ast
  module Template
    # Merge dispatch: route a file type to its merger adapter. Contract:
    # structuredmerge/spec slice-1043, fixtures at
    # structuredmerge/fixtures/templating/slice-1043-merge-dispatch.
    #
    # Default adapters wrap the ast-merge family gems and are required LAZILY —
    # ast-template does not hard-depend on merger gems; the consumer's bundle
    # provides them. Types needing consumer policy (gemspec, the Ruby family,
    # json variants, dotenv, rbs, bash, gitignore) have no default adapter —
    # register one.
    module MergeDispatch
      Adapter = Struct.new(:gem_name, :require_path, :invoke)

      DEFAULT_ADAPTERS = {
        yaml: Adapter.new('psych-merge', 'psych/merge', lambda { |t, d, **opts|
          Psych::Merge.merge_yaml(t, d, 'yaml', **opts)
        }),
        toml: Adapter.new('citrus-toml-merge', 'citrus/toml/merge', lambda { |t, d, **opts|
          Citrus::Toml::Merge.merge_toml(t, d, 'toml', **opts)
        }),
        markdown: Adapter.new('markdown-merge', 'markdown/merge', lambda { |t, d, **opts|
          Markdown::Merge.merge_markdown(t, d, 'markdown', **opts)
        })
      }.freeze

      @adapters = {}

      class << self
        # Register an adapter for a file type. The callable receives
        # (template_content, destination_content, **options) and returns the
        # merger result hash ({ok:, output:, diagnostics:}).
        def register(file_type, callable = nil, &block)
          adapter = callable || block
          raise ArgumentError, 'adapter callable required' unless adapter.respond_to?(:call)

          adapters[file_type.to_sym] = adapter
        end

        # Whether any adapter (registered or default) exists for the type.
        def registered?(file_type)
          adapters.key?(file_type.to_sym) || DEFAULT_ADAPTERS.key?(file_type.to_sym)
        end

        # Dispatch to the type's adapter. Returns nil when no adapter exists —
        # the caller's fallback is the template content.
        #
        # @return [Hash, nil] the merger result, or nil when unregistered
        def dispatch(file_type, template_content, destination_content, **options)
          type = file_type.to_sym
          registered = adapters[type]
          return registered.call(template_content, destination_content, **options) if registered

          default = DEFAULT_ADAPTERS[type]
          return nil unless default

          begin
            require default.require_path
          rescue LoadError
            raise LoadError, "merge dispatch for #{type} requires #{default.gem_name}; add it to the consumer bundle"
          end
          default.invoke.call(template_content, destination_content, **options)
        end

        # Test support: clear consumer-registered adapters.
        def reset!
          @adapters = {}
        end

        private

        def adapters
          @adapters ||= {}
        end
      end
    end
  end
end
