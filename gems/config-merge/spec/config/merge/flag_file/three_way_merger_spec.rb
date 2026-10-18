# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength -- keep the option-policy behavior matrix together
RSpec.describe Config::Merge::FlagFile::ThreeWayMerger do
  def policy(flags = {})
    Config::Merge::Policy.new(
      "defaults" => { "cardinality" => "repeatable", "on_conflict" => "union" },
      "flags" => flags
    )
  end

  it "keeps a destination-owned singleton flag and adds independent template options" do
    result = described_class.new(
      base: "--format progress\n--require spec_helper\n",
      ours: "--format progress\n--require rails_helper\n",
      theirs: "--format progress\n--require spec_helper\n--exclude-pattern spec/tmp/**/*_spec.rb\n",
      policy: policy("--require" => { "cardinality" => "single", "on_conflict" => "ours" })
    ).merge

    expect(result).to be_success
    expect(result.output).to include("--require rails_helper")
    expect(result.output).to include("--exclude-pattern spec/tmp/**/*_spec.rb")
    expect(result.output).not_to include("--require spec_helper")
  end

  it "merges independent additions to a repeatable flag without collapsing records" do
    result = described_class.new(
      base: "--env BASE=1\n",
      ours: "--env BASE=1\n--env OURS=1\n",
      theirs: "--env BASE=1\n--env THEIRS=1\n",
      policy: policy
    ).merge

    expect(result.output.lines.grep(/--env/)).to contain_exactly("--env BASE=1\n", "--env OURS=1\n", "--env THEIRS=1\n")
  end

  it "preserves repeated identical entries already present in a side" do
    result = described_class.new(
      base: "--env BASE=1\n",
      ours: "--env BASE=1\n--env EXTRA=1\n--env EXTRA=1\n",
      theirs: "--env BASE=1\n--env EXTRA=1\n",
      policy: policy
    ).merge

    expect(result.output.lines.grep(/EXTRA/).length).to eq(2)
  end

  it "reports an unresolved conflict and withholds a final output" do
    result = described_class.new(
      base: "--require spec_helper\n",
      ours: "--require rails_helper\n",
      theirs: "--require test_helper\n",
      policy: policy("--require" => { "cardinality" => "single", "on_conflict" => "conflict" })
    ).merge

    expect(result).not_to be_success
    expect(result.output).to be_nil
    expect(result.conflicts.map(&:flag)).to eq(["--require"])
    expect(result.conflicts.first.ours.first.value).to eq("rails_helper")
    expect(result.conflicts.first.theirs.first.value).to eq("test_helper")
  end

  it "uses a registered normalizer for comparison" do
    result = described_class.new(
      base: "--require spec_helper\n",
      ours: "--require rails_helper\n",
      theirs: "--require rails_helper\n",
      policy: policy("--require" => { "cardinality" => "single", "normalizer" => "strip" })
    ).merge

    expect(result.output).to include("--require rails_helper")
  end

  it "preserves comments from the input documents" do
    result = described_class.new(
      base: "# base\n--color\n",
      ours: "# destination\n--color\n",
      theirs: "# template\n--color\n",
      policy: policy
    ).merge

    expect(result.output).to include("# destination", "# template")
  end
end
# rubocop:enable Metrics/BlockLength
