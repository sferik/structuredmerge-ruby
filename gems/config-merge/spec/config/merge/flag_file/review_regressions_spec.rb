# frozen_string_literal: true

RSpec.describe Config::Merge::FlagFile::ThreeWayMerger do
  def merge_same(source, policy: Config::Merge::Policy.new({}))
    described_class.new(base: source, ours: source, theirs: source, policy: policy).merge
  end

  it "keeps quoted positional paths as one shell argument" do
    result = merge_same(%("spec/my spec.rb"\n))

    expect(Shellwords.shellsplit(result.output)).to eq(["spec/my spec.rb"])
  end

  it "preserves empty equals arguments" do
    result = merge_same("--example=\n")

    expect(Shellwords.shellsplit(result.output)).to eq(["--example="])
    expect(Config::Merge::FlagFile::Parser.new.parse(result.output).options.first.value).to eq("")
  end
end

RSpec.describe Config::Merge::FlagFile::ThreeWayMerger do
  def merge_same(source, policy: Config::Merge::Policy.new({}))
    described_class.new(base: source, ours: source, theirs: source, policy: policy).merge
  end

  it "preserves equals binding for arguments beginning with a dash" do
    result = merge_same("--example=-foo\n")

    expect(Shellwords.shellsplit(result.output)).to eq(["--example=-foo"])
    expect(Config::Merge::FlagFile::Parser.new.parse(result.output).options.first.value).to eq("-foo")
  end

  it "honors a one-sided repeatable option reorder" do
    base = "--env A=1\n--env B=1\n"
    theirs = "--env B=1\n--env A=1\n"
    policy = Config::Merge::Policy.new(
      "defaults" => { "cardinality" => "repeatable", "on_conflict" => "conflict" },
      "flags" => { "--env" => { "cardinality" => "repeatable", "on_conflict" => "union" } }
    )

    result = described_class.new(base: base, ours: base, theirs: theirs, policy: policy).merge

    expect(result.output.lines.map { |line| Shellwords.shellsplit(line) }).to eq([["--env", "B=1"], ["--env", "A=1"]])
  end
end

RSpec.describe Config::Merge::FlagFile::ThreeWayMerger do
  it "leaves divergent undeclared flags unresolved by default" do
    policy = Config::Merge::Policy.new({})
    result = described_class.new(
      base: "--seed 1\n",
      ours: "--seed 2\n",
      theirs: "--seed 3\n",
      policy: policy
    ).merge

    expect(result).not_to be_success
    expect(result.conflicts.map(&:flag)).to eq(["--seed"])
  end

  it "keeps unknown RSpec flags conservative" do
    result = described_class.new(
      base: "--seed 1\n",
      ours: "--seed 2\n",
      theirs: "--seed 3\n",
      policy: Config::Merge::BuiltInPolicies.fetch(:rspec)
    ).merge

    expect(result).not_to be_success
    expect(result.conflicts.map(&:flag)).to eq(["--seed"])
  end
end
