# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength -- focused policy validation examples
RSpec.describe Config::Merge::Policy do
  describe ".load" do
    it "loads validated rules and named normalizers from YAML" do
      path = File.expand_path("../../fixtures/rspec-policy.yml", __dir__)
      policy = described_class.load(path)

      expect(policy.name).to eq("rspec")
      expect(policy.rule_for("--require").cardinality).to eq(:single)
      expect(policy.rule_for("--require").on_conflict).to eq(:ours)
      expect(policy.rule_for("--require").normalizer).to eq(:strip)
    end
  end

  it "rejects union for singleton flags" do
    expect do
      described_class.new("flags" => { "--require" => { "cardinality" => "single", "on_conflict" => "union" } })
    end.to raise_error(ArgumentError, /single-valued flags cannot use the union/)
  end

  it "rejects unknown normalizer names before merge execution" do
    expect do
      described_class.new("flags" => { "--require" => { "normalizer" => "eval" } })
    end.to raise_error(ArgumentError, /unknown normalizer/)
  end

  it "rejects unsupported policy formats" do
    expect { described_class.new("format" => "yaml") }
      .to raise_error(ArgumentError, /unsupported policy format/)
  end

  it "rejects unknown policy keys" do
    expect do
      described_class.new("unexpected" => true)
    end.to raise_error(ArgumentError, /unknown policy key/)
  end
end

# rubocop:enable Metrics/BlockLength
