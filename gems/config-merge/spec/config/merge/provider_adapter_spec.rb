# frozen_string_literal: true

require "spec_helper"
require "psych/merge"

RSpec.describe Config::Merge::ProviderAdapter do
  it "reuses the registered Psych provider and preserves provider output details" do
    adapter = described_class.new(
      family: :yaml,
      dialect: :yaml,
      backend: :psych,
      profile_id: :source_preserving
    )
    base = "# retained\nalpha: base\nbeta: base\n"
    ours = "# retained\nalpha: ours\nbeta: base\nours_only: left\n"
    theirs = "# retained\nalpha: base\nbeta: theirs\ntheirs_only: right\n"

    result = adapter.merge3(base: base, ours: ours, theirs: theirs)

    expect(result).to include(
      ok: true,
      output: "# retained\nalpha: ours\nbeta: theirs\nours_only: left\ntheirs_only: right\n"
    )
    expect(result.dig(:verification, :base_participated)).to be(true)
    expect(result.dig(:verification, :semantic_match)).to be(true)
    expect(result.dig(:render_report, :strategy)).to eq(:exact_mapping_entry_composite)
  end
end
