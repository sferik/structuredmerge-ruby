# ast-crispr-yaml-psych

`ast-crispr-yaml-psych` connects [ast-crispr](https://github.com/structuredmerge/structuredmerge-ruby) to `psych-merge`, providing YAML structural owners and selectors for AST-aware edits.

## Synopsis

`ast-crispr-yaml-psych` connects [ast-crispr](https://github.com/structuredmerge/structuredmerge-ruby) to `psych-merge`. It provides structural owners and selectors for editing YAML by mapping entry or sequence item while retaining YAML layout and comments.

## Configuration

Require the gem in your Ruby application; it registers the YAML/Psych adapter with ast-crispr:

```ruby
require "ast-crispr-yaml-psych"
```

No separate configuration file is needed. Selectors take a `path` array of mapping keys and, for sequence items, a zero-based `index`. Use an array so keys containing dots are treated as single keys. Available owner scopes include `:mapping_entries`, `:nested_mapping_entries`, and `:sequence_items`.

## Basic Usage

```ruby
require "ast-crispr-yaml-psych"

source = <<~YAML
  jobs:
    test:
      strategy:
        matrix:
          include:
            - os: ubuntu-latest
            - os: macos-latest
YAML

target = Ast::Crispr::Yaml::Psych::Selectors.sequence_item(
  path: %w[jobs test strategy matrix include],
  index: 1
)

result = Ast::Crispr::Delete.result(content: source, target: target)
puts result.updated_content
```

The selector identifies the second item under `jobs.test.strategy.matrix.include`; `Ast::Crispr::Delete.result` performs the structural edit. Nested sibling groups retain their layout gaps through `psych-merge`, preserving separator and blank-line ownership at each YAML level.

## Development

Run the gem's specs from this directory with `bundle exec kettle-test`. The monorepo root Gemfile includes the gem for family-level development.
