# frozen_string_literal: true

require "open3"
require "rbconfig"
require "stringio"

load File.expand_path("../../bin/kettle-jem-deps-floor", __dir__)

RSpec.describe KettleJemDepsFloor do
  it "delegates arguments and Kettle Jem defaults to the shared CLI" do
    calls = []
    allow(Kettle::Deps::Floor::CLI).to receive(:run) do |received_arguments, **options|
      calls << [received_arguments, options]
      0
    end
    arguments = %w[--check --upgrade patch]
    out = StringIO.new
    err = StringIO.new

    status = described_class.run(arguments, out: out, err: err)

    expect(status).to eq(0)
    received_arguments, options = calls.fetch(0)
    expect(received_arguments).to eq(arguments)
    expect(options).to include(out: out, err: err)
    expect(options.fetch(:defaults)).to include(
      executable: "kettle-jem-deps-floor",
      project_root: File.expand_path("..", File.dirname(File.expand_path("../../bin/kettle-jem-deps-floor", __dir__))),
      config_name: ".kettle-jem-deps-floor.yml",
      changelog_key: "kettle-jem-deps-floor",
      changelog_entry: "Update kettle-jem template dependency floors:"
    )
  end

  it "scans the packaged template sources and kettle-jem dependency registries by default" do
    sources = described_class::DEFAULTS.fetch(:sources)

    expect(sources).to include(
      "lib/kettle/jem/templates/gem.gemspec.example",
      "lib/kettle/jem/templates/gemfiles/**/*.gemfile.example",
      "lib/kettle/jem.rb"
    )
  end

  it "keeps the repository-local executable runnable from the Kettle Jem checkout" do
    gem_root = File.expand_path("..", File.dirname(File.expand_path("../../bin/kettle-jem-deps-floor", __dir__)))
    executable = File.join(gem_root, "bin", "kettle-jem-deps-floor")
    stdout, stderr, status = Open3.capture3(
      {},
      RbConfig.ruby,
      executable,
      "--help",
      chdir: gem_root
    )

    expect(status.success?).to be(true), "stdout=#{stdout}\nstderr=#{stderr}"
    expect(stdout).to include("Usage: kettle-jem-deps-floor")
    expect(stderr).not_to include("already initialized constant")
  end
end
