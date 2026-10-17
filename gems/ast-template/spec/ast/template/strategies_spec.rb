# frozen_string_literal: true

# Conformance specs for the slice-1042 strategy application contract.
# Cases come from the shared fixture manifest; do not add inline cases here —
# extend the fixture so every host runs the same contract.
RSpec.describe Ast::Template::Strategies do
  search_root = Pathname(__dir__).expand_path
  search_root = search_root.parent until search_root.join('fixtures').directory? || search_root.parent.join('fixtures').directory? || search_root.root?
  fixture_root = search_root.join('fixtures')
  fixture_root = search_root.parent.join('fixtures') unless fixture_root.directory?
  raise "structuredmerge fixtures not found from #{__dir__}" unless fixture_root.directory?

  manifest = JSON.parse(
    fixture_root.join('templating/slice-1042-strategy-application/manifest.json').read,
    symbolize_names: true
  )

  manifest.fetch(:resolution_cases).each do |fixture_case|
    it "resolve: #{fixture_case[:name]}" do
      result = described_class.resolve(
        default: fixture_case[:default],
        overrides: fixture_case[:overrides],
        path: fixture_case[:path]
      )
      expect(result).to eq(fixture_case[:expected])
    end
  end

  manifest.fetch(:application_cases).each do |fixture_case|
    it "plan_entry: #{fixture_case[:name]}" do
      result = described_class.plan_entry(
        strategy: fixture_case[:strategy],
        template_content: fixture_case[:template_content],
        destination_content: fixture_case[:destination_content]
      )
      expected = fixture_case[:expected]
      expect(result[:execution_action]).to eq(expected[:execution_action])
      expect(result[:write_action]).to eq(expected[:write_action])
      expect(result[:status]).to eq(expected[:status])
      expect(result[:content]).to eq(expected[:content])
    end
  end

  describe '.keep_destination?' do
    it 'is true only for keep_destination' do
      expect(described_class.keep_destination?('keep_destination')).to be(true)
      expect(described_class.keep_destination?('merge')).to be(false)
      expect(described_class.keep_destination?(nil)).to be(false)
    end
  end

  describe '.trivial_merge_outcome' do
    it 'classifies empty, absent, identical, and differing destinations' do
      expect(described_class.trivial_merge_outcome('t', '')).to eq(:empty_destination)
      expect(described_class.trivial_merge_outcome('t', nil)).to eq(:empty_destination)
      expect(described_class.trivial_merge_outcome('t', '  ')).to eq(:empty_destination)
      expect(described_class.trivial_merge_outcome('t', 't')).to eq(:identical)
      expect(described_class.trivial_merge_outcome('t', 'other')).to be_nil
    end
  end
end
