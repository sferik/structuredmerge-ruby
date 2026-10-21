# frozen_string_literal: true

require "anonymous_loader"
require "ast-crispr-toml"
RSpec.describe Ast::Crispr::Toml::Version do
  it "has a version" do
    expect(described_class::VERSION).not_to be_nil
  end

  it "matches the traditional constant location" do
    expect(Ast::Crispr::Toml::VERSION).to eq(described_class::VERSION)
  end

  it "executes the version file for coverage without redefining constants" do
    dir = File.expand_path("../../../../lib/ast/crispr/toml", __dir__)
    paths = %w[version.rb version_gem.rb].map { |file| File.join(dir, file) }.select { |path| File.file?(path) }
    anonymous_namespace = AnonymousLoader.load(files: paths)

    expect(anonymous_namespace::Ast::Crispr::Toml::Version::VERSION).to eq(described_class::VERSION)
  end
end
