# frozen_string_literal: true

RSpec.describe Config::Merge::FlagFile::Parser do
  subject(:document) { described_class.new.parse(source) }

  let(:source) do
    <<~OPTIONS
      # RSpec options
      --format progress
      --require=rails_helper
      --out "results/test results.html"
      --color
    OPTIONS
  end

  it "parses flags with separate and equals-form arguments" do
    expect(document.options.map { |option| [option.flag, option.value] }).to eq(
      [["--format", "progress"], ["--require", "rails_helper"], ["--out", "results/test results.html"],
       ["--color", nil]]
    )
  end

  it "retains comment and blank lines as opaque source records" do
    expect(document.opaque_lines.map(&:last)).to include("# RSpec options")
  end

  it "reports malformed shell quoting with a line number" do
    expect { described_class.new.parse("--require 'unterminated\n") }
      .to raise_error(described_class::ParseError, /line 1/)
  end
end
