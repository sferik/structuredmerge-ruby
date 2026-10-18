# frozen_string_literal: true

require "ast/crispr/yaml/psych"
require "version_gem"
require_relative "ast/crispr/yaml/psych/version"

Ast::Crispr::Yaml::Psych::Version.class_eval do
  extend VersionGem::Basic
end
