# frozen_string_literal: true

# Conformance specs for the slice-1043 file-type detection and merge dispatch
# contract. Cases come from the shared fixture manifest; do not add inline
# cases here — extend the fixture so every host runs the same contract.
RSpec.describe 'slice-1043 file-type detection and merge dispatch' do
  search_root = Pathname(__dir__).expand_path
  search_root = search_root.parent until search_root.join('fixtures').directory? || search_root.parent.join('fixtures').directory? || search_root.root?
  fixture_root = search_root.join('fixtures')
  fixture_root = search_root.parent.join('fixtures') unless fixture_root.directory?
  raise "structuredmerge fixtures not found from #{__dir__}" unless fixture_root.directory?

  manifest = JSON.parse(
    fixture_root.join('templating/slice-1043-merge-dispatch/manifest.json').read,
    symbolize_names: true
  )

  describe Ast::Template::FileTypes do
    manifest.fetch(:detection_cases).each do |fixture_case|
      it fixture_case[:name] do
        expect(described_class.detect(fixture_case[:path], configured: fixture_case[:configured]))
          .to eq(fixture_case[:expected].to_sym)
      end
    end
  end

  describe Ast::Template::MergeDispatch do
    after { described_class.reset! }

    manifest.fetch(:dispatch_cases).each do |fixture_case|
      it fixture_case[:name] do
        options = fixture_case.fetch(:options, {}).to_h.transform_keys(&:to_sym)
        # Fixture option values are JSON scalars; enum options map to symbols.
        options[:preference] = options[:preference].to_sym if options.key?(:preference)
        result = described_class.dispatch(
          fixture_case[:file_type],
          fixture_case[:template_content],
          fixture_case[:destination_content],
          **options
        )
        expected = fixture_case[:expected]
        if expected[:nil]
          expect(result).to be_nil
        else
          expect(result[:ok]).to be(true)
          expected.fetch(:output_contains).each do |fragment|
            expect(result[:output]).to include(fragment)
          end
          Array(expected[:output_excludes]).each do |fragment|
            expect(result[:output]).not_to include(fragment)
          end
        end
      end
    end

    it 'lets a consumer register an adapter for a policy type' do
      described_class.register(:gemspec) { |t, d, **_opts| {ok: true, output: "#{t}|#{d}", diagnostics: []} }

      result = described_class.dispatch(:gemspec, 'a', 'b')

      expect(result[:output]).to eq('a|b')
    end

    it 'reports the gem to add when a default adapter is unloadable' do
      allow(described_class).to receive(:require).and_call_original
      allow(described_class).to receive(:require).with('psych/merge').and_raise(LoadError)

      expect { described_class.dispatch(:yaml, 'a: 1', 'b: 2') }
        .to raise_error(LoadError, /psych-merge/)
    end
  end
end
