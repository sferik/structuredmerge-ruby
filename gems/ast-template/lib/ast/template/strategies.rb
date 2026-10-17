# frozen_string_literal: true

module Ast
  module Template
    # Strategy resolution and application decisions for template entries.
    # Contract: structuredmerge/spec slice-1042, conformance fixtures at
    # structuredmerge/fixtures/templating/slice-1042-strategy-application.
    #
    # The vocabulary (execution_action / write_action / status) matches the
    # slice-353 session transport fixtures. The merger itself is the next
    # contract surface (slice-1043); `merge` on differing content stops at
    # the decision here.
    module Strategies
      # The four strategy names a destination config may declare.
      STRATEGIES = %w[merge keep_destination raw_copy accept_template].freeze
      DEFAULT_STRATEGY = "merge"

      module_function

      # Effective strategy for a destination path: the matching override wins,
      # else the default. Overrides are TemplateStrategyOverride-shaped
      # entries ({path:, strategy:} with string or symbol keys).
      #
      # @param default [String] strategy when no override matches
      # @param overrides [Array<Hash>] per-path strategy overrides
      # @param path [String] logical destination path
      # @return [String] the effective strategy
      def resolve(default: DEFAULT_STRATEGY, overrides: [], path:)
        override = Array(overrides).find { |entry| (entry[:path] || entry["path"]) == path }
        strategy = override && (override[:strategy] || override["strategy"])
        strategy.to_s.empty? ? default : strategy.to_s
      end

      # The decision for one entry. Content is present only when this contract
      # owns it (raw_copy, accept_template, merge-with-empty-destination);
      # keep decisions and merge-of-differences return no content (the latter
      # defers to the merger).
      #
      # @param strategy [String] resolved strategy for the entry
      # @param template_content [String] prepared template content
      # @param destination_content [String, nil] current destination content
      #   (nil when the destination file is absent)
      # @return [Hash] {execution_action:, write_action:, status:, content:}
      def plan_entry(strategy:, template_content:, destination_content:)
        strategy = strategy.to_s
        return keep_decision if strategy == "keep_destination"

        absent = destination_content.nil?
        if strategy == "merge"
          trivial = trivial_merge_outcome(template_content, destination_content)
          return keep_decision if trivial == :identical
          return write_decision("merge_prepared_content", absent, template_content) if trivial == :empty_destination
        end

        # accept_template and merge-of-differences both write prepared content;
        # for merge-of-differences the content is the merger's, not ours.
        content = (strategy == "merge") ? nil : template_content
        write_decision(execution_action_for(strategy), absent, content)
      end

      # Whether the strategy leaves the destination untouched. Absent
      # destinations are not created under keep_destination.
      def keep_destination?(strategy)
        strategy.to_s == "keep_destination"
      end

      # The merge short-circuits that never invoke a merger:
      # :empty_destination when there is nothing to merge into (template
      # becomes the content), :identical when destination already equals
      # template (destination is kept), nil when a real merge is required.
      def trivial_merge_outcome(template_content, destination_content)
        return :empty_destination if destination_content.to_s.strip.empty?
        return :identical if destination_content == template_content

        nil
      end

      def keep_decision
        {execution_action: "keep", write_action: "keep", status: "keep", content: nil}
      end

      def write_decision(execution_action, create, content)
        action = create ? "create" : "update"
        {execution_action: execution_action, write_action: action, status: action, content: content}
      end

      def execution_action_for(strategy)
        (strategy == "raw_copy") ? "raw_copy" : "merge_prepared_content"
      end
    end
  end
end
