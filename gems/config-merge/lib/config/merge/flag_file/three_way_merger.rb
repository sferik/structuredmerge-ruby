# frozen_string_literal: true

require_relative "parser"
require_relative "result"

module Config
  module Merge
    module FlagFile
      # Merges option records using base-aware per-flag policy.
      #
      # The conventional roles are base, ours (the destination/current side), and
      # theirs (the incoming side). Rules compare normalized values while output
      # retains original option spelling, argument text, comments, and blank lines.
      class ThreeWayMerger
        attr_reader :base, :ours, :theirs, :policy

        def initialize(base:, ours:, theirs:, policy:)
          @parser = Parser.new
          @base = parse(base)
          @ours = parse(ours)
          @theirs = parse(theirs)
          @policy = policy
        end

        def merge
          decisions = merge_decisions
          partial = render(decisions.fetch(:selected))
          conflicts = decisions.fetch(:conflicts)
          Result.new(output: conflicts.empty? ? partial : nil, conflicts: conflicts, partial_output: partial)
        end

        private

        def merge_decisions
          DecisionEngine.new(base: base, ours: ours, theirs: theirs, policy: policy).merge
        end

        def render(selected)
          output = OutputRenderer.new(selected, base: base, ours: ours, theirs: theirs, policy: policy).render
          output += "\n" if !output.empty? && trailing_newline?
          output
        end

        def parse(value)
          value.is_a?(Document) ? value : @parser.parse(value)
        end

        def trailing_newline?
          return ours.trailing_newline if ours.trailing_newline == theirs.trailing_newline
          return theirs.trailing_newline if ours.trailing_newline == base.trailing_newline

          ours.trailing_newline
        end
      end

      # Makes per-flag base/ours/theirs decisions.
      class DecisionEngine
        def initialize(base:, ours:, theirs:, policy:)
          @base = base
          @ours = ours
          @theirs = theirs
          @policy = policy
        end

        def merge
          selected = {}
          conflicts = []
          flags.each do |flag|
            chosen, conflict = choose(flag, options(@base, flag), options(@ours, flag), options(@theirs, flag))
            selected[flag] = chosen if chosen
            conflicts << conflict if conflict
          end
          { selected: selected, conflicts: conflicts }
        end

        private

        def flags
          (@base.options + @ours.options + @theirs.options).map(&:flag).uniq
        end

        def options(document, flag)
          document.options.select { |option| option.flag == flag }
        end

        def choose(flag, base, ours, theirs)
          rule = @policy.rule_for(flag)
          base_key = semantic_options(base, rule)
          ours_key = semantic_options(ours, rule)
          theirs_key = semantic_options(theirs, rule)
          return [sourced(ours, :ours), nil] if ours_key == theirs_key || theirs_key == base_key
          return [sourced(theirs, :theirs), nil] if ours_key == base_key
          if rule.cardinality == :repeatable && rule.on_conflict == :union
            return [merge_repeatable(base, ours, theirs, rule), nil]
          end

          resolve_conflict(flag, base, ours, theirs, rule)
        end

        def resolve_conflict(flag, base, ours, theirs, rule)
          case rule.on_conflict
          when :ours then [sourced(ours, :ours), nil]
          when :theirs then [sourced(theirs, :theirs), nil]
          when :base then [sourced(base, :base), nil]
          when :union then [stable_union(ours, theirs, rule), nil]
          when :conflict then [nil, Conflict.new(flag: flag, base: base, ours: ours, theirs: theirs)]
          end
        end

        def merge_repeatable(base, ours, theirs, rule)
          counts = [base, ours, theirs].map { |options| option_counts(options, rule) }
          keys = counts.flat_map(&:keys).uniq
          targets = keys.to_h { |key| [key, target_count(key, counts)] }
          select_records(targets, [[ours, :ours], [theirs, :theirs], [base, :base]], rule)
        end

        def target_count(key, counts)
          base_count, ours_count, theirs_count = counts.map { |count| count.fetch(key, 0) }
          removed = [base_count - ours_count, base_count - theirs_count, 0].max
          added = [ours_count - base_count, theirs_count - base_count, 0].max
          [base_count - removed, 0].max + added
        end

        def stable_union(ours, theirs, rule)
          seen = {}
          sourced(ours, :ours).concat(sourced(theirs, :theirs)).each_with_object([]) do |(option, source), selected|
            key = semantic_key(option, rule)
            next if seen[key]

            seen[key] = true
            selected << [option, source]
          end
        end

        def select_records(targets, sources, rule)
          remaining = targets.dup
          sources.each_with_object([]) do |(options, source), selected|
            options.each do |option|
              key = semantic_key(option, rule)
              next unless remaining.fetch(key, 0).positive?

              selected << [option, source]
              remaining[key] -= 1
            end
          end
        end

        def sourced(options, source)
          options.map { |option| [option, source] }
        end

        def option_counts(options, rule)
          options.each_with_object(Hash.new(0)) { |option, counts| counts[semantic_key(option, rule)] += 1 }
        end

        def semantic_options(options, rule)
          options.map { |option| semantic_key(option, rule) }
        end

        def semantic_key(option, rule)
          [option.flag, NormalizerRegistry.normalize(rule.normalizer, option.value)]
        end
      end

      # Renders selected records in destination order and retains opaque source lines.
      class OutputRenderer
        def initialize(selected, base:, ours:, theirs:, policy:)
          @selected = selected
          @documents = [[ours, 0], [theirs, 1], [base, 2]]
          @policy = policy
        end

        def render
          records.sort_by do |line_number, source_rank, position, sequence, _raw|
            [line_number, source_rank, position, sequence]
          end
                 .map(&:last).join("\n")
        end

        private

        def records
          @opaque_remaining = opaque_counts
          @sequence = 0
          selected_records + @documents.flat_map do |document, source_rank|
            opaque_records(document, source_rank)
          end
        end

        def selected_records
          @selected.flat_map do |_flag, entries|
            entries.map do |option, source|
              record(option.line_number, source_rank(source), option.position, option.raw)
            end
          end
        end

        def source_rank(source)
          { ours: 0, theirs: 1, base: 2 }.fetch(source)
        end

        def opaque_records(document, source_rank)
          document.opaque_lines.filter_map do |line_number, position, raw|
            next unless @opaque_remaining.fetch(raw, 0).positive?

            @opaque_remaining[raw] -= 1
            record(line_number, source_rank, position, raw)
          end
        end

        def record(line_number, source_rank, position, raw)
          value = [line_number, source_rank, position, @sequence, raw]
          @sequence += 1
          value
        end

        def opaque_counts
          base_counts = line_counts(@documents[2].first)
          ours_counts = line_counts(@documents[0].first)
          theirs_counts = line_counts(@documents[1].first)
          keys = base_counts.keys | ours_counts.keys | theirs_counts.keys
          keys.to_h { |raw| [raw, merged_line_count(raw, base_counts, ours_counts, theirs_counts)] }
        end

        def line_counts(document)
          document.opaque_lines.each_with_object(Hash.new(0)) do |(_line, _position, raw), result|
            result[raw] += 1
          end
        end

        def merged_line_count(raw, base_counts, ours_counts, theirs_counts)
          base_count = base_counts.fetch(raw, 0)
          ours_count = ours_counts.fetch(raw, 0)
          theirs_count = theirs_counts.fetch(raw, 0)
          return ours_count if ours_count == theirs_count
          return theirs_count if ours_count == base_count
          return ours_count if theirs_count == base_count

          [ours_count, theirs_count].max
        end
      end
    end
  end
end
