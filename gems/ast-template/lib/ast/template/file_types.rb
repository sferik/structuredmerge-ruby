# frozen_string_literal: true

module Ast
  module Template
    # Destination-path file-type detection. Contract: structuredmerge/spec
    # slice-1043, fixtures at
    # structuredmerge/fixtures/templating/slice-1043-merge-dispatch.
    #
    # First match wins; the rule order is load-bearing (e.g. `.gemfile`
    # shadows the appraisals rule for `Appraisal.root.gemfile` — preserved
    # from kettle-jem's effective behavior and documented in the slice).
    module FileTypes
      RUBY_BASENAMES = %w[Gemfile Rakefile Appraisals Appraisal.root.gemfile .simplecov].freeze
      RUBY_SUFFIXES = %w[.gemspec .gemfile].freeze
      RUBY_EXTENSIONS = %w[.rb .rake].freeze

      module_function

      # @param path [String] logical destination path
      # @param configured [String, Symbol, nil] destination-config override
      # @return [Symbol] the file type
      def detect(path, configured: nil)
        return configured.to_sym unless configured.to_s.empty?

        relative_path = path.to_s
        basename = File.basename(relative_path)
        extension = File.extname(relative_path).downcase
        return :gitignore if basename == ".gitignore"
        return :gemfile if basename == "Gemfile" || basename.end_with?(".gemfile")
        return :appraisals if basename.start_with?("Appraisals")
        return :gemspec if basename.end_with?(".gemspec")
        return :rakefile if basename == "Rakefile" || extension == ".rake"
        return :ruby if RUBY_BASENAMES.include?(basename) ||
          RUBY_SUFFIXES.any? { |suffix| basename.end_with?(suffix) } ||
          RUBY_EXTENSIONS.include?(extension)
        return :yaml if extension.match?(/\A\.ya?ml\z/) || basename.casecmp("citation.cff").zero?
        return :toml if extension == ".toml"
        return :jsonc if relative_path == ".devcontainer/devcontainer.json"
        return :jsonc if extension == ".jsonc"
        return :json5 if extension == ".json5"
        return :json if extension == ".json"
        return :markdown if extension.match?(/\A\.md(?:own)?\z/)
        return :dotenv if basename.start_with?(".env") || basename.end_with?(".env") || extension == ".env"
        return :rbs if extension == ".rbs"

        :text
      end
    end
  end
end
