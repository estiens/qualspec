# frozen_string_literal: true

require_relative 'lib/qualspec/version'

Gem::Specification.new do |spec|
  spec.name = 'qualspec'
  spec.version = Qualspec::VERSION
  spec.authors = ['Eric Stiens']
  spec.email = ['estiens@users.noreply.github.com']

  spec.summary = 'RSpec DSL for qualitative LLM-judged testing'
  spec.description = 'Define qualitative evaluation criteria and let an LLM judge if responses pass. Perfect for testing AI agents, comparing models, and evaluating subjective qualities.'
  spec.homepage = 'https://github.com/estiens/qualspec'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'faraday', '~> 2.0'

  # Optional: only needed for recording/playback features
  spec.add_development_dependency 'vcr', '~> 6.0'
  spec.add_development_dependency 'webmock', '~> 3.0'
end
