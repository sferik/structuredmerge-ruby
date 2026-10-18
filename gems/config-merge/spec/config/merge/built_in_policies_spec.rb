# frozen_string_literal: true

RSpec.describe Config::Merge::BuiltInPolicies do
  describe ".names" do
    it "lists the bundled policy profiles" do
      expect(described_class.names).to include(:rspec)
    end
  end

  describe ".fetch" do
    it "returns the RSpec flag policy" do
      policy = described_class.fetch(:rspec)

      expect(policy.name).to eq("rspec")
      expect(policy.rule_for("--require").cardinality).to eq(:single)
      expect(policy.rule_for("--require").on_conflict).to eq(:ours)
      expect(policy.rule_for("--env").cardinality).to eq(:repeatable)
    end

    it "rejects unknown and unsafe profile names" do
      expect { described_class.fetch(:missing) }.to raise_error(ArgumentError, /Unknown built-in policy/)
      expect { described_class.fetch("../rspec") }.to raise_error(ArgumentError, /Unknown built-in policy/)
    end
  end
end
