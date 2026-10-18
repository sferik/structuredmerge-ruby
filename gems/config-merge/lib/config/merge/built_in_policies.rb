# frozen_string_literal: true

require_relative "policy"

module Config
  module Merge
    # Bundled policy catalog for common configuration formats.
    module BuiltInPolicies
      POLICY_DIRECTORY = File.join(__dir__, "policies").freeze

      module_function

      def names
        Dir.glob(File.join(POLICY_DIRECTORY, "*.yml")).map do |path|
          File.basename(path, ".yml").to_sym
        end.sort.freeze
      end

      def fetch(name)
        key = name.to_s
        raise ArgumentError, "Unknown built-in policy: #{name}" unless key.match?(/\A[a-z0-9_-]+\z/)

        path = File.join(POLICY_DIRECTORY, "#{key}.yml")
        raise ArgumentError, "Unknown built-in policy: #{name}" unless File.file?(path)

        Policy.load(path)
      end
    end
  end
end
