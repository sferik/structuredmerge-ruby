# frozen_string_literal: true

module Config
  module Merge
    module FlagFile
      Conflict = Struct.new(:flag, :base, :ours, :theirs, keyword_init: true) do
        def initialize(flag:, base:, ours:, theirs:)
          super(flag: flag, base: base.freeze, ours: ours.freeze, theirs: theirs.freeze)
          freeze
        end
      end

      # Result of a semantic flag-file merge.
      class Result
        attr_reader :output, :conflicts, :partial_output

        def initialize(output:, conflicts:, partial_output:)
          @output = output
          @conflicts = conflicts.freeze
          @partial_output = partial_output
          freeze
        end

        def clean?
          conflicts.empty?
        end

        alias success? clean?
      end
    end
  end
end
