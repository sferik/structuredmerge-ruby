# frozen_string_literal: true

RSpec.describe Config::Merge::NormalizerRegistry do
  describe ".normalize" do
    it "provides stable built-in normalizers" do
      expect(described_class.normalize(:identity, " Value ")).to eq(" Value ")
      expect(described_class.normalize(:strip, " Value ")).to eq("Value")
      expect(described_class.normalize(:downcase, "Value")).to eq("value")
    end

    it "allows trusted Ruby extensions to register named callables" do
      described_class.register(:spec_test_normalizer) { |value| value.to_s.reverse }

      expect(described_class.normalize(:spec_test_normalizer, "abc")).to eq("cba")
    end

    it "rejects unknown names and duplicate registrations" do
      expect { described_class.normalize(:missing, "value") }
        .to raise_error(described_class::UnknownNormalizerError, /Unknown normalizer/)
      described_class.register(:single_registration) { |value| value }
      expect { described_class.register(:single_registration) { |value| value } }
        .to raise_error(ArgumentError, /already registered/)
    end
  end
end
