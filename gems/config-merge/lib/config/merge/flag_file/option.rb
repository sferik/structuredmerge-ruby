# frozen_string_literal: true

module Config
  module Merge
    module FlagFile
      # One parsed flag and its optional argument.
      Option = Struct.new(:flag, :value, :raw, :line_number, :position, :binding, keyword_init: true) do
        def initialize(**attributes)
          attributes[:position] ||= 0
          attributes[:binding] ||= :none
          super(**attributes)
          freeze
        end

        def to_s
          raw
        end
      end

      # Parsed flag-file contents. Opaque lines are comments, blank lines, and positional arguments.
      Document = Struct.new(:options, :opaque_lines, :trailing_newline, keyword_init: true) do
        def initialize(options:, opaque_lines:, trailing_newline: false)
          super(options: options.freeze, opaque_lines: opaque_lines.freeze, trailing_newline: trailing_newline == true)
          freeze
        end
      end
    end
  end
end
