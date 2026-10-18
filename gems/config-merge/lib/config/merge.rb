# frozen_string_literal: true

require "version_gem"
require_relative "merge/version"

module Config
  module Merge
    class Error < StandardError; end
    # Your code goes here...
  end
end

Config::Merge::Version.class_eval do
  extend VersionGem::Basic
end
