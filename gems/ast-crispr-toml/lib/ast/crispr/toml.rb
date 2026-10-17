# frozen_string_literal: true

require "ast/crispr"
require "toml/merge"
require_relative "toml/version"

module Ast
  module Crispr
    # TOML adapter for AST CRISPR structural edits.
    #
    # Backed by `toml-merge`'s FileAnalysis, which normalizes over the
    # available TOML parser backends (tree-sitter via TreeHaver, Citrus,
    # Parslet). Owners are TOML tables (including array-of-tables and dotted
    # sub-tables) and key/value pairs addressed by dotted key paths.
    module Toml
      class Error < StandardError; end

      # Byte range of a structural owner. 1-based, inclusive.
      Location = Struct.new(:start_line, :end_line, keyword_init: true)

      # A `[table]` / `[[table_array]]` block owner. `location.start_line`
      # includes the block's leading comment lines; `location.end_line` is the
      # clamped body end (the last line the table owns, not the next header).
      TableOwner = Struct.new(:location, :name, :kind, :leading_region, :wrapper, keyword_init: true)

      # A `key = value` pair owner, addressed by its dotted path from the
      # document root (e.g. `tasks.family-lint.run`).
      PairOwner = Struct.new(:location, :name, :full_path, :wrapper, keyword_init: true)

      class Adapter
        def read_ast(document)
          analysis = ::Toml::Merge::FileAnalysis.new(document.content)
          return analysis if analysis.valid?

          raise Ast::Crispr::Error.new("Unable to read structural owners from #{document.source_label}",
            details: {source_label: document.source_label})
        end

        def structural_owners(document, owner_scope: :shared_default)
          analysis = document.ast
          case owner_scope
          when :shared_default, :tables
            analysis.tables.map { |wrapper| table_owner(analysis, wrapper) }
          when :root_pairs
            analysis.root_pairs.map { |wrapper| pair_owner(nil, wrapper) }
          when :pairs
            analysis.root_pairs.map { |wrapper| pair_owner(nil, wrapper) } +
              analysis.tables.flat_map do |table|
                table.pairs.map { |wrapper| pair_owner(table, wrapper) }
              end
          else
            raise Ast::Crispr::Error.new("Unsupported CRISPR owner scope", details: {owner_scope: owner_scope})
          end
        end

        def comment_regions_for(document, owner, region: :leading, owner_scope: :shared_default)
          analysis = document.ast
          case region
          when :leading then attachment_for(analysis, owner).leading_region
          when :trailing then attachment_for(analysis, owner).trailing_region
          else
            raise Ast::Crispr::Error.new(
              "Unsupported CRISPR comment region",
              details: {region: region, owner_scope: owner_scope}
            )
          end
        end

        def comment_region_text(_document, comment_region)
          comment_region.text
        end

        def structure_profile(owner_scope: :shared_default)
          case owner_scope
          when :shared_default, :tables
            Ast::Crispr::StructureProfile.new(
              owner_scope: owner_scope,
              owner_selector: :tables,
              supported_comment_regions: %i[leading trailing],
              metadata: {adapter: :toml}
            )
          when :root_pairs
            Ast::Crispr::StructureProfile.new(
              owner_scope: owner_scope,
              owner_selector: :root_pairs,
              supported_comment_regions: %i[leading trailing],
              metadata: {adapter: :toml, toml_owner: :root_pair}
            )
          when :pairs
            Ast::Crispr::StructureProfile.new(
              owner_scope: owner_scope,
              owner_selector: :pairs,
              supported_comment_regions: %i[leading trailing],
              metadata: {adapter: :toml, toml_owner: :pair}
            )
          else
            raise Ast::Crispr::Error.new("Unsupported CRISPR owner scope", details: {owner_scope: owner_scope})
          end
        end

        private

        def attachment_for(analysis, owner)
          analysis.comment_attachment_for(owner.wrapper)
        end

        def table_owner(analysis, wrapper)
          attachment = analysis.comment_attachment_for(wrapper)
          leading = attachment.leading_region
          TableOwner.new(
            location: Location.new(
              start_line: leading ? leading.start_line : wrapper.start_line,
              end_line: wrapper.effective_end_line
            ),
            name: wrapper.table_name,
            kind: wrapper.array_of_tables? ? :table_array : :table,
            leading_region: leading,
            wrapper: wrapper
          )
        end

        def pair_owner(parent_table, wrapper)
          parent_path = parent_table ? split_path(parent_table.table_name) : []
          full_path = parent_path + split_path(wrapper.key_name.to_s)
          PairOwner.new(
            location: Location.new(start_line: wrapper.start_line, end_line: wrapper.end_line),
            name: wrapper.key_name,
            full_path: full_path.join("."),
            wrapper: wrapper
          )
        end

        def split_path(dotted)
          dotted.to_s.split(".").map(&:strip).reject(&:empty?)
        end
      end

      # Selectors for TOML structural owners. Paths are dotted strings
      # (`tasks.family-lint`, `tasks.family-lint.run`, `min_version`).
      module Selectors
        module_function

        def table(path:, id: nil, limit: nil, metadata: {}, **options)
          Ast::Crispr::OwnerSelector.new(
            id: id || "table_#{path}",
            limit: limit,
            metadata: metadata.merge(
              adapter: Ast::Crispr::Toml.adapter,
              owner_scope: :tables,
              selector_kind: :table,
              selection_intent: :predicate_filter,
              include_trailing_gap: false
            ).merge(options),
            locate: lambda do |context|
              context.structural_owners(owner_scope: :tables).filter_map do |owner|
                next unless owner.name.to_s == path.to_s

                Ast::Crispr::Match.new(
                  node: owner,
                  start_line: owner.location.start_line,
                  end_line: owner.location.end_line,
                  metadata: {
                    start_boundary: :owner_start,
                    end_boundary: :owner_end,
                    payload_kind: :table_block,
                    table_name: owner.name,
                    kind: owner.kind
                  }
                )
              end
            end
          )
        end

        def pair(path:, id: nil, limit: nil, metadata: {}, **options)
          Ast::Crispr::OwnerSelector.new(
            id: id || "pair_#{path}",
            limit: limit,
            metadata: metadata.merge(
              adapter: Ast::Crispr::Toml.adapter,
              owner_scope: :pairs,
              selector_kind: :pair,
              selection_intent: :predicate_filter,
              include_trailing_gap: false
            ).merge(options),
            locate: lambda do |context|
              context.structural_owners(owner_scope: :pairs).filter_map do |owner|
                next unless owner.full_path == normalize_path(path)

                Ast::Crispr::Match.new(
                  node: owner,
                  start_line: owner.location.start_line,
                  end_line: owner.location.end_line,
                  metadata: {
                    start_boundary: :owner_start,
                    end_boundary: :owner_end,
                    payload_kind: :structural_owner_body,
                    key_name: owner.name,
                    full_path: owner.full_path
                  }
                )
              end
            end
          )
        end

        def normalize_path(path)
          path.to_s.split(".").map(&:strip).reject(&:empty?).join(".")
        end
      end

      Targets = Selectors

      class << self
        def adapter
          @adapter ||= Adapter.new
        end

        def document_context(content:, source_label: "source", metadata: {}, **options)
          Ast::Crispr::DocumentContext.new(
            content: content,
            source_label: source_label,
            adapter: adapter,
            metadata: metadata,
            **options
          )
        end
      end
    end
  end
end
