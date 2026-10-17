# frozen_string_literal: true

require "ast/crispr/toml"
require "version_gem"
require_relative "ast/crispr/toml/version"

Ast::Crispr::Toml::Version.class_eval do
  extend VersionGem::Basic
end
