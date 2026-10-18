# frozen_string_literal: true

require "ast/merge"
require "version_gem"
require_relative "merge/version"
require_relative "merge/normalizer_registry"
require_relative "merge/policy"
require_relative "merge/built_in_policies"
require_relative "merge/flag_file/option"
require_relative "merge/flag_file/parser"
require_relative "merge/flag_file/result"
require_relative "merge/flag_file/three_way_merger"

module Config
  module Merge
    # Base error class for config-merge.
    class Error < Ast::Merge::Error; end
  end
end

Config::Merge::Version.class_eval do
  extend VersionGem::Basic
end

require_relative "merge/provider_adapter"
