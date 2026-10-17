# frozen_string_literal: true

RSpec.describe Ast::Crispr::Toml do
  let(:source) do
    <<~TOML
      # Root comment about min_version
      min_version = "4.0"

      [tasks]
      clean = "echo clean"

      # Comment about the family lint task
      [tasks.family-lint]
      run = "bin/rake lint"

      [[items]]
      name = "a"
    TOML
  end

  let(:context) { described_class.document_context(content: source, source_label: "mise.toml") }

  describe "Adapter#read_ast" do
    it "returns a toml-merge FileAnalysis for valid TOML" do
      expect(context.ast).to be_a(::Toml::Merge::FileAnalysis)
      expect(context.ast).to be_valid
    end

    it "raises a CRISPR error for unparseable TOML" do
      expect {
        described_class.document_context(content: "this is not toml =\n= = =\n", source_label: "broken.toml").ast
      }.to raise_error(Ast::Crispr::Error, /Unable to read structural owners/)
    end
  end

  describe "Adapter#structural_owners" do
    it "exposes tables (including dotted sub-tables and array tables) with clamped ranges" do
      owners = context.structural_owners(owner_scope: :tables)

      expect(owners.map(&:name)).to eq(%w[tasks tasks.family-lint items])
      expect(owners.map(&:kind)).to eq(%i[table table table_array])

      tasks = owners.first
      # Starts at its own header (no leading comments), body ends at `clean = ...`
      expect(tasks.location.start_line).to eq(4)
      expect(tasks.location.end_line).to eq(5)

      family_lint = owners[1]
      # Starts at its leading comment line, body ends at its `run = ...` pair
      expect(family_lint.location.start_line).to eq(7)
      expect(family_lint.location.end_line).to eq(9)
    end

    it "exposes root pairs and in-table pairs addressed by dotted paths" do
      owners = context.structural_owners(owner_scope: :pairs)

      expect(owners.map(&:full_path)).to contain_exactly(
        "min_version", "tasks.clean", "tasks.family-lint.run", "items.name"
      )
      min_version = owners.find { |owner| owner.full_path == "min_version" }
      expect(min_version.location.start_line).to eq(2)
      expect(min_version.location.end_line).to eq(2)
    end

    it "exposes root pairs through the root_pairs scope" do
      owners = context.structural_owners(owner_scope: :root_pairs)

      expect(owners.map(&:full_path)).to eq(["min_version"])
    end

    it "raises for an unsupported owner scope" do
      expect { context.structural_owners(owner_scope: :nonsense) }
        .to raise_error(Ast::Crispr::Error, /Unsupported CRISPR owner scope/)
    end
  end

  describe "Selectors.table" do
    it "selects a table by dotted path, including its leading comments" do
      selector = described_class::Selectors.table(path: "tasks.family-lint")
      matches = selector.locate_matches(context)

      expect(matches.size).to eq(1)
      expect(matches.first.line_range).to eq(7..9)
      expect(matches.first.metadata[:payload_kind]).to eq(:table_block)
    end

    it "does not match a parent path when selecting a sub-table" do
      selector = described_class::Selectors.table(path: "tasks.family-lint")

      expect(selector.locate_matches(context).map(&:line_range)).not_to include(4..5)
    end

    it "supports removal through the core Delete actor" do
      selector = described_class::Selectors.table(path: "tasks.family-lint")
      result = Ast::Crispr::Delete.result(content: source, target: selector, source_label: "mise.toml")

      expect(result).to be_success
      expect(result.updated_content).not_to include("tasks.family-lint")
      expect(result.updated_content).not_to include("Comment about the family lint task")
      expect(result.updated_content).to include("[tasks]")
      expect(result.updated_content).to include("[[items]]")
      expect { ::Toml::Merge::FileAnalysis.new(result.updated_content) }.not_to raise_error
      expect(::Toml::Merge::FileAnalysis.new(result.updated_content)).to be_valid
    end
  end

  describe "Selectors.pair" do
    it "selects a nested pair by full dotted path" do
      selector = described_class::Selectors.pair(path: "tasks.family-lint.run")
      matches = selector.locate_matches(context)

      expect(matches.size).to eq(1)
      expect(matches.first.line_range).to eq(9..9)
      expect(matches.first.metadata[:full_path]).to eq("tasks.family-lint.run")
    end

    it "selects a root-level pair" do
      selector = described_class::Selectors.pair(path: "min_version")

      expect(selector.locate_matches(context).map(&:line_range)).to eq([2..2])
    end

    it "supports removal through the core Delete actor" do
      selector = described_class::Selectors.pair(path: "tasks.clean")
      result = Ast::Crispr::Delete.result(content: source, target: selector, source_label: "mise.toml")

      expect(result).to be_success
      expect(result.updated_content).not_to include("echo clean")
      expect(result.updated_content).to include("family-lint")
    end
  end

  describe "Adapter#comment_regions_for" do
    it "returns the leading comment region for a table owner" do
      owners = context.structural_owners(owner_scope: :tables)
      family_lint = owners[1]
      region = context.adapter.comment_regions_for(context, family_lint, region: :leading, owner_scope: :tables)

      expect(region).not_to be_nil
      expect(region.start_line).to eq(7)
      expect(context.adapter.comment_region_text(context, region)).to include("Comment about the family lint task")
    end

    it "raises for an unsupported region" do
      owners = context.structural_owners(owner_scope: :tables)

      expect { context.adapter.comment_regions_for(context, owners.first, region: :inline, owner_scope: :tables) }
        .to raise_error(Ast::Crispr::Error, /Unsupported CRISPR comment region/)
    end
  end

  describe "Adapter#structure_profile" do
    it "describes the tables scope" do
      profile = context.adapter.structure_profile(owner_scope: :tables)

      expect(profile.owner_scope).to eq(:tables)
      expect(profile.owner_selector).to eq(:tables)
      expect(profile.supported_comment_regions).to include(:leading)
      expect(profile.metadata[:adapter]).to eq(:toml)
    end
  end
end
