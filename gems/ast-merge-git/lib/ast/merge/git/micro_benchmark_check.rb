# frozen_string_literal: true

require 'json'

module Ast
  module Merge
    module Git
      # Verifies the paired-drivers micro benchmark invariants outside the spec
      # suite. Runs the real benchmark machinery (installed driver, real merge
      # cases), so it is only invoked by the explicit `benchmark:micro` rake
      # task — never by RSpec. See rakelib/benchmark_micro.rake.
      class MicroBenchmarkCheck
        # ok: true when every invariant held; checks: name => true/String(failure detail)
        Result = Struct.new(:ok, :checks, keyword_init: true)

        CONFLICT_CASE = 'case.merge3.json.independent-fields.v1'
        OWNER_CONFLICT_CASE = 'case.merge3.json.same-owner-conflict.v1'
        MALFORMED_CASE = 'case.merge3.json.malformed-ours.v1'

        # @param runner [#run] an Ast::Merge::Git::LocalBenchmarkRunner
        # @param options [Hash] reserved for forward compatibility
        def initialize(runner, **options)
          @runner = runner
          @options = options
        end

        # Builds a runner from explicit paths and verifies the invariants.
        #
        # @param corpus_path [String, Pathname] benchmark corpus JSON
        # @param driver_path [String, Pathname] installed ast-merge-git driver
        # @param tmp_root [String, Pathname] scratch directory for runs
        # @param options [Hash] reserved for forward compatibility
        def self.call(corpus_path:, driver_path:, tmp_root:, **options)
          runner = LocalBenchmarkRunner.new(
            benchmark: LocalBenchmark.load(corpus_path),
            driver_path: driver_path,
            tmp_root: tmp_root
          )
          new(runner, **options).verify
        end

        # Runs the micro profile (twice, for cache-identity stability) and
        # checks the safety invariants. Never raises for a failed invariant —
        # failures are reported through the returned Result.
        #
        # @return [Result]
        def verify
          cwd_before = Dir.pwd
          runs = Array.new(2) { @runner.run(profile: 'micro') }
          checks = invariant_checks(runs, cwd_before)
          Result.new(ok: checks.values.all?(true), checks: checks)
        rescue LocalBenchmark::Error => e
          Result.new(ok: false, checks: { 'benchmark run' => e.message })
        end

        private

        def invariant_checks(runs, cwd_before)
          {
            'git text conflict becomes a structurally verified clean candidate' =>
              conflict_check(runs.first),
            'intentional-conflict safety and malformed-input rejection preserved' =>
              safety_check(runs.first),
            'cwd preserved, JSON-serializable, stable cache identity' =>
              stability_check(runs, cwd_before)
          }
        end

        def conflict_check(run)
          results = results_for(run, CONFLICT_CASE)
          last = results.last
          outcomes(results) == %w[false_conflict correct_clean] &&
            last.dig('checks', 'parse_validity_only_accepted') == false &&
            last.dig('checks', 'acceptable') == true &&
            last.fetch('deterministic_correctness_rerun') == true
        rescue StandardError
          false
        end

        def safety_check(run)
          conflict = results_for(run, OWNER_CONFLICT_CASE)
          malformed = results_for(run, MALFORMED_CASE).last
          outcomes(conflict) == %w[true_conflict true_conflict] &&
            malformed['outcome'] == 'correct_clean' &&
            messages_of(malformed).include?('ours parse error')
        rescue StandardError
          false
        end

        def stability_check(runs, cwd_before)
          first = runs.first
          last = runs.last
          Dir.pwd == cwd_before &&
            first.dig('cache_identity', 'sha256') == last.dig('cache_identity', 'sha256') &&
            !JSON.generate(first).nil?
        rescue StandardError
          false
        end

        def results_for(run, case_id)
          run.fetch('results').select { |item| item['case_id'] == case_id }
        end

        def outcomes(records)
          records.map { |item| item['outcome'] }
        end

        def messages_of(record)
          record.fetch('diagnostics').map { |item| item['message'] }.join
        end
      end
    end
  end
end
