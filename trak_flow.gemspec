# frozen_string_literal: true

require_relative 'lib/trak_flow/version'

Gem::Specification.new do |spec|
  spec.name          = 'trak_flow'
  spec.version       = TrakFlow::VERSION
  spec.authors       = ['Dewayne VanHoozer']
  spec.email         = ['dewayne@vanhoozer.me']

  spec.summary       = 'A distributed task tracking system for Robots'
  spec.description   = <<~DESC
    TrakFlow is a specialized task tracking system designed for robots.
    It implements a dependency-aware graph, allowing
    robots to handle complex/lengthy task workflows without losing context. Tasks are
    stored as JSONL files within a designated directory, using Git as the
    underlying database for versioning, branching, and merging.
  DESC
  spec.homepage      = 'https://github.com/madbomber/trak_flow'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github])
    end
  end
  spec.bindir        = 'bin'
  spec.executables   = ['tf', 'tf_mcp']
  spec.require_paths = ['lib']

  spec.add_dependency 'anyway_config', '~> 2.0'
  spec.add_dependency 'debug_me'
  spec.add_dependency 'fast-mcp'
  spec.add_dependency 'oj', '~> 3.16'
  spec.add_dependency 'pastel', '~> 0.8'
  spec.add_dependency 'sequel', '~> 5.0'
  spec.add_dependency 'sqlite3', '~> 2.0'
  spec.add_dependency 'thor', '~> 1.3'
  spec.add_dependency 'tty-spinner', '~> 0.9'
  spec.add_dependency 'tty-table', '~> 0.12'
  spec.add_dependency 'puma', '~> 6.0'
  spec.add_dependency 'rackup', '~> 2.0'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'minitest-reporters', '~> 1.6'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.add_development_dependency 'simplecov', '~> 0.22'
end
