# frozen_string_literal: true

# Conformance specs for the slice-1041 token application contract.
# Cases come from the shared fixture manifest; do not add inline cases here —
# extend the fixture so every host runs the same contract.
RSpec.describe Ast::Template::TokenApplication do
  # The fixtures checkout may be under the local container or a sibling of the
  # repository checkout in CI. Ascend rather than counting path segments.
  search_root = Pathname(__dir__).expand_path
  search_root = search_root.parent until search_root.join('fixtures').directory? || search_root.parent.join('fixtures').directory? || search_root.root?
  fixture_root = search_root.join('fixtures')
  fixture_root = search_root.parent.join('fixtures') unless fixture_root.directory?
  raise "structuredmerge fixtures not found from #{__dir__}" unless fixture_root.directory?

  manifest = JSON.parse(
    fixture_root.join('templating/slice-1041-token-application/manifest.json').read,
    symbolize_names: true
  )

  def self.config_for(fixture_config)
    Token::Resolver::Config.new(
      pre: fixture_config[:pre],
      post: fixture_config[:post],
      separators: fixture_config[:separators],
      min_segments: fixture_config[:min_segments]
    )
  end

  manifest.fetch(:cases).each do |fixture_case|
    config = config_for(fixture_case[:config])
    namespace = fixture_case[:namespace]
    scan_unresolved = fixture_case[:scan_unresolved]
    input = fixture_case[:input]
    replacements = fixture_case[:replacements]
    expected = fixture_case[:expected]

    it fixture_case[:name] do
      if expected[:error]
        expected_tokens = expected[:error].fetch(:tokens).map(&:to_s)
        error = nil
        begin
          described_class.apply_tokens(input, replacements, config: config, namespace: namespace, scan_unresolved: scan_unresolved)
        rescue Ast::Template::TokenApplication::UnresolvedTokensError => e
          error = e
        end
        expect(error).not_to be_nil
        expect(error.tokens).to eq(expected_tokens)
        expected_tokens.each do |token|
          expect(error.message).to include("{#{token}}")
        end
      else
        output = described_class.apply_tokens(input, replacements, config: config, namespace: namespace, scan_unresolved: scan_unresolved)
        expect(output).to eq(expected.fetch(:output))
      end
    end
  end

  describe '.unresolved_namespaced_tokens' do
    let(:config) { Token::Resolver::Config.new(separators: ['|', ':']) }

    it 'returns sorted canonical keys for the namespace only' do
      content = '{KJ|B} {OTHER|X} {KJ|A} {KJ|B}'
      expect(described_class.unresolved_namespaced_tokens(content, config: config, namespace: 'KJ'))
        .to eq(['KJ|A', 'KJ|B'])
    end

    it 'returns an empty list when no namespaced tokens are present' do
      expect(described_class.unresolved_namespaced_tokens('plain', config: config, namespace: 'KJ')).to eq([])
    end
  end

  describe '.stringify_replacements' do
    it 'stringifies keys and values' do
      expect(described_class.stringify_replacements({:'KJ|N' => 3})).to eq({'KJ|N' => '3'})
    end
  end
end
