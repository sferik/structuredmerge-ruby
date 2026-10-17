# frozen_string_literal: true

require_relative 'spec_helper'
require 'json'

# rubocop:disable Metrics/BlockLength, Metrics/MethodLength -- canned run data and example grouping are intentionally explicit
RSpec.describe Ast::Merge::Git::MicroBenchmarkCheck do
  # Canned micro-profile run shaped to satisfy the invariants. The check class
  # is verified with a fake runner — the REAL benchmark machinery must never
  # execute in the spec suite; it belongs to `bundle exec rake benchmark:micro`.
  def canned_run(cache_id)
    {
      'cache_identity' => { 'sha256' => cache_id },
      'results' => [
        {
          'case_id' => 'case.merge3.json.independent-fields.v1',
          'outcome' => 'false_conflict'
        },
        {
          'case_id' => 'case.merge3.json.independent-fields.v1',
          'outcome' => 'correct_clean',
          'checks' => { 'parse_validity_only_accepted' => false, 'acceptable' => true },
          'deterministic_correctness_rerun' => true
        },
        {
          'case_id' => 'case.merge3.json.same-owner-conflict.v1',
          'outcome' => 'true_conflict'
        },
        {
          'case_id' => 'case.merge3.json.same-owner-conflict.v1',
          'outcome' => 'true_conflict'
        },
        {
          'case_id' => 'case.merge3.json.malformed-ours.v1',
          'outcome' => 'correct_clean',
          'diagnostics' => [{ 'message' => 'rejected: ours parse error' }]
        }
      ]
    }
  end

  let(:runner) do
    double('LocalBenchmarkRunner', run: canned_run('stable-cache-id'))
  end

  describe '.call' do
    it 'builds a runner from the corpus and delegates to verify' do
      runner_instance = double('runner')
      benchmark = double('benchmark')
      allow(Ast::Merge::Git::LocalBenchmark).to receive(:load).with('corpus.json').and_return(benchmark)
      allow(Ast::Merge::Git::LocalBenchmarkRunner).to receive(:new)
        .with(benchmark: benchmark, driver_path: 'driver', tmp_root: 'tmp')
        .and_return(runner_instance)
      allow(runner_instance).to receive(:run).with(profile: 'micro').and_return(canned_run('id'))

      result = described_class.call(corpus_path: 'corpus.json', driver_path: 'driver', tmp_root: 'tmp')

      expect(result.ok).to be(true)
      expect(result.checks.values).to all(be(true))
      expect(Ast::Merge::Git::LocalBenchmark).to have_received(:load).with('corpus.json')
    end
  end

  describe '#verify' do
    it 'reports every invariant ok for a healthy micro run' do
      result = described_class.new(runner).verify

      expect(result.ok).to be(true)
      expect(result.checks.values).to all(be(true))
      expect(runner).to have_received(:run).with(profile: 'micro').twice
    end

    it 'fails when a conflicting case stops being a false conflict' do
      bad = canned_run('stable-cache-id')
      bad['results'].first['outcome'] = 'correct_clean'
      strict_runner = double('runner')
      allow(strict_runner).to receive(:run).with(profile: 'micro').and_return(bad)

      result = described_class.new(strict_runner).verify

      expect(result.ok).to be(false)
      expect(result.checks['git text conflict becomes a structurally verified clean candidate']).to be(false)
    end

    it 'fails when cache identity drifts between runs' do
      calls = 0
      drifting_runner = double('runner')
      allow(drifting_runner).to receive(:run).with(profile: 'micro') do
        calls += 1
        canned_run("cache-id-#{calls}")
      end

      result = described_class.new(drifting_runner).verify

      expect(result.ok).to be(false)
      expect(result.checks['cwd preserved, JSON-serializable, stable cache identity']).to be(false)
    end

    it 'reports a benchmark error as a failed check instead of raising' do
      error_runner = double('runner')
      allow(error_runner).to receive(:run)
        .with(profile: 'micro')
        .and_raise(Ast::Merge::Git::LocalBenchmark::Error, 'git version differs: git version 9.9.9')
      result = described_class.new(error_runner).verify

      expect(result.ok).to be(false)
      expect(result.checks['benchmark run']).to include('version differs')
    end
  end
end

# rubocop:enable Metrics/BlockLength, Metrics/MethodLength
