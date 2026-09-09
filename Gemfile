# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem 'ruby_llm'
gem 'ruby_llm-mcp'

group :development, :test do
  # Optional HTTP-transport gems for the MCP server — kept out of the
  # gemspec on purpose (consumers opt in); needed here so bin/tf_mcp's
  # HTTP mode works during development.
  gem 'puma', '>= 7.2.1'
  gem 'rackup'

  # Quality-gate tools invoked via `bundle exec` by the asgard quality task.
  gem 'fasterer'
  gem 'reek'
end
