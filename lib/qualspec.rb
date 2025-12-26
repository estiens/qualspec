# frozen_string_literal: true

require_relative 'qualspec/version'

module Qualspec
  class Error < StandardError; end
end

require_relative 'qualspec/configuration'
require_relative 'qualspec/client'
require_relative 'qualspec/evaluation'
require_relative 'qualspec/prompt_variant'
require_relative 'qualspec/rubric'
require_relative 'qualspec/judge'
require_relative 'qualspec/builtin_rubrics'
require_relative 'qualspec/suite/candidate'
require_relative 'qualspec/suite/scenario'
require_relative 'qualspec/suite/behavior'
require_relative 'qualspec/suite/dsl'
require_relative 'qualspec/suite/runner'
require_relative 'qualspec/suite/reporter'
require_relative 'qualspec/suite/html_reporter'
require_relative 'qualspec/suite/builtin_behaviors'
require_relative 'qualspec/recorder'

module Qualspec
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset!
      @configuration = nil
      @client = nil
      @judge = nil
      Rubric.clear!
      Suite.clear!
      Suite::Behavior.clear!
    end

    def client
      @client ||= Client.new(configuration)
    end

    def judge
      @judge ||= Judge.new
    end

    # Convenience method for defining rubrics
    def define_rubric(name, &block)
      Rubric.define(name, &block)
    end

    # Convenience method for defining behaviors
    def define_behavior(name, &block)
      Suite::Behavior.define(name, &block)
    end

    # Convenience method for defining evaluation suites
    def evaluation(name, &block)
      Suite.define(name, &block)
    end

    # Run an evaluation suite
    def run(suite_name, progress: true, output: :stdout, json_path: nil, html_path: nil, show_responses: false,
            load_builtins: true)
      # Load builtins (idempotent, can be called multiple times)
      if load_builtins
        BuiltinRubrics.load!
        Suite::BuiltinBehaviors.load!
      end

      suite = Suite.find(suite_name)
      runner = Suite::Runner.new(suite)

      results = runner.run(progress: progress)
      results.finish!

      reporter = Suite::Reporter.new(results, show_responses: show_responses)

      case output
      when :stdout
        puts reporter.to_stdout
      when :json
        puts reporter.to_json
      when :silent
        # nothing
      end

      reporter.write_json(json_path) if json_path

      if html_path
        html_reporter = Suite::HtmlReporter.new(results)
        html_reporter.write(html_path)
      end

      results
    end
  end
end
