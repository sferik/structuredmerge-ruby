# frozen_string_literal: true

# Explicit micro-benchmark task for the paired local drivers. This runs the
# REAL benchmark machinery and is deliberately NOT part of the RSpec suite —
# invoke it by hand: `bundle exec rake benchmark:micro`.

# Walks up from the gem root looking for the shared fixtures checkout.
# @return [String, nil] absolute corpus.json path
def benchmark_micro_corpus(gem_root)
  dir = gem_root
  5.times do
    candidate = File.join(dir, 'fixtures', 'diagnostics', 'slice-1023-local-paired-benchmark', 'corpus.json')
    return candidate if File.file?(candidate)

    dir = File.dirname(dir)
  end
  nil
end

namespace :benchmark do
  desc 'Run the paired-drivers micro benchmark and verify its safety invariants (explicit; not part of the spec suite)'
  task :micro do
    gem_root = File.expand_path('..', __dir__)
    corpus_path = ENV['AST_MERGE_GIT_CORPUS'] || benchmark_micro_corpus(gem_root)
    abort 'benchmark corpus not found; set AST_MERGE_GIT_CORPUS to the corpus.json path' unless corpus_path

    require 'ast/merge/git'
    require 'ast/merge/git/micro_benchmark_check'
    driver_path = File.join(gem_root, 'exe', 'ast-merge-git')
    driver_path = Gem.bin_path('ast-merge-git', 'ast-merge-git') unless File.executable?(driver_path)
    tmp_root = File.join(gem_root, 'tmp', 'benchmark-micro')

    result = Ast::Merge::Git::MicroBenchmarkCheck.call(
      corpus_path: corpus_path,
      driver_path: driver_path,
      tmp_root: tmp_root
    )
    result.checks.each do |name, outcome|
      puts "#{outcome == true ? '✅' : '❌'} #{name}#{outcome == true ? '' : " — #{outcome}"}"
    end
    abort 'micro benchmark invariants FAILED' unless result.ok

    puts 'micro benchmark ok'
  end
end
