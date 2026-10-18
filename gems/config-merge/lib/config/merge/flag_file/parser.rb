# frozen_string_literal: true

require "shellwords"
require_relative "option"

module Config
  module Merge
    module FlagFile
      # Parses shell-style option records, one or more per line.
      class Parser
        class ParseError < ArgumentError; end

        def parse(source)
          options = []
          opaque_lines = []
          source.to_s.each_line.with_index(1) do |raw_line, line_number|
            parsed_options, opaque = parse_line(raw_line.chomp, line_number)
            options.concat(parsed_options)
            opaque_lines.concat(opaque)
          end

          Document.new(options: options, opaque_lines: opaque_lines, trailing_newline: source.to_s.end_with?("\n"))
        end

        private

        def parse_line(line, line_number)
          return [[], [[line_number, line].freeze]] if line.strip.empty? || line.strip.start_with?("#")

          parse_options(line, line_number)
        rescue ArgumentError => e
          raise ParseError, "Invalid option syntax on line #{line_number}: #{e.message}"
        end

        def parse_options(line, line_number)
          tokens = Shellwords.shellsplit(line)
          options, opaque = consume_tokens(tokens, line_number)
          [options, opaque]
        end

        def consume_tokens(tokens, line_number)
          options = []
          opaque = []
          index = 0
          while index < tokens.length
            option, consumed = parse_option(tokens, index, line_number)
            option ? options << option : opaque << [line_number, tokens[index]].freeze
            index += consumed
          end
          [options, opaque]
        end

        def parse_option(tokens, index, line_number)
          token = tokens[index]
          return [nil, 1] unless token.start_with?("-")

          flag, value = parse_flag_token(token)
          consumed = 1
          if value.nil? && tokens[index + 1] && !tokens[index + 1].start_with?("-")
            value = tokens[index + 1]
            consumed += 1
          end
          [Option.new(flag: flag, value: value, raw: render(flag, value), line_number: line_number), consumed]
        end

        def parse_flag_token(token)
          flag, separator, value = token.partition("=")
          [flag, separator.empty? ? nil : value]
        end

        def render(flag, value)
          return Shellwords.escape(flag) if value.nil?

          rendered_value = value.match?(/[\s\\"']/) ? Shellwords.escape(value) : value
          "#{Shellwords.escape(flag)} #{rendered_value}"
        end
      end
    end
  end
end
