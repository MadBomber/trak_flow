#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo: TrakFlow MCP Server with STDIO Transport
#
# This example shows how to connect to the TrakFlow MCP server
# using STDIO transport with the ruby_llm and ruby_llm-mcp gems.
#
# Prerequisites:
#   - Ollama running: ollama serve
#   - Model available: ollama pull gpt-oss (or set OLLAMA_MODEL env var)
#
# Usage:
#   cd examples/mcp
#   bundle install
#   ruby stdio_demo.rb

require "bundler/setup"
require "ruby_llm"
require "ruby_llm/mcp"
require "tmpdir"
require "fileutils"

# Configure RubyLLM to use Ollama
RubyLLM.configure do |config|
  config.ollama_api_base = ENV["OLLAMA_API_BASE"] || ENV["OLLAMA_URL"] || "http://localhost:11434/v1"
end

# Model configuration
OLLAMA_MODEL = ENV.fetch("OLLAMA_MODEL", "gpt-oss:latest")

# Path to the TrakFlow MCP server executable and project root
PROJECT_ROOT = File.expand_path("../..", __dir__)
TF_MCP_PATH = File.join(PROJECT_ROOT, "bin/tf_mcp")
TF_CLI_PATH = File.join(PROJECT_ROOT, "bin/tf")
GEMFILE_PATH = File.join(PROJECT_ROOT, "Gemfile")

puts "TrakFlow MCP STDIO Demo"
puts "=" * 40
puts

# Create a temp directory and initialize TrakFlow there
WORK_DIR = Dir.mktmpdir("trakflow_mcp_demo")
puts "Working directory: #{WORK_DIR}"

# Initialize TrakFlow in the temp directory
Dir.chdir(WORK_DIR) do
  system({ "BUNDLE_GEMFILE" => GEMFILE_PATH }, "bundle", "exec", TF_CLI_PATH, "init", out: File::NULL, err: File::NULL)
end

puts "TrakFlow initialized."
puts

# Create MCP client with STDIO transport
# Use a shell wrapper to cd to work dir and run with proper bundle
client = RubyLLM::MCP.client(
  name: "trakflow",
  transport_type: :stdio,
  config: {
    command: "/bin/sh",
    args: ["-c", "cd #{WORK_DIR} && BUNDLE_GEMFILE=#{GEMFILE_PATH} bundle exec #{TF_MCP_PATH}"]
  }
)

begin
  # The client connects automatically on creation
  puts "Connected to TrakFlow MCP server via STDIO..."
  puts "Connection alive: #{client.alive?}"

  # List available tools
  puts "\nAvailable Tools:"
  puts "-" * 40
  client.tools.each do |tool|
    puts "  - #{tool.name}: #{tool.description}"
  end

  # List available resources
  puts "\nAvailable Resources:"
  puts "-" * 40
  client.resources.each do |resource|
    puts "  - #{resource.uri}: #{resource.name}"
  end

  # Example: Create a task using the MCP tool
  puts "\n" + "=" * 40
  puts "Creating a test task..."
  puts "-" * 40

  tool = client.tool("task_create")
  result = tool.execute(
    title: "Demo task from STDIO",
    description: "Created via MCP STDIO transport demo"
  )

  puts "Result: #{result}"

  # Extract the task ID from the creation result
  result_str = result.to_s
  task_id = result_str.match(/id: "([^"]+)"/)[1] rescue nil

  # Example: Start the task to demonstrate a second tool call
  if task_id
    puts "\n" + "=" * 40
    puts "Starting the task via MCP tool..."
    puts "-" * 40

    start_tool = client.tool("task_start")
    start_result = start_tool.execute(id: task_id)
    puts "Task started: #{start_result}"

    # Close the task
    puts "\n" + "=" * 40
    puts "Closing the task via MCP tool..."
    puts "-" * 40

    close_tool = client.tool("task_close")
    close_result = close_tool.execute(id: task_id)
    puts "Task closed: #{close_result}"
  end

  # Example: Use with RubyLLM chat (optional - requires Ollama)
  if ENV["SKIP_LLM"] != "1"
    puts "\n" + "=" * 40
    puts "Sending prompt to LLM with MCP tools..."
    puts "-" * 40

    chat = RubyLLM.chat(model: OLLAMA_MODEL, provider: :ollama, assume_model_exists: true)
    chat.with_tools(*client.tools)
    response = chat.ask("Use the available tools to list all tasks and summarize what you find.")

    puts "\nLLM Response:"
    puts response.content
  else
    puts "\n" + "=" * 40
    puts "Skipping LLM test (SKIP_LLM=1)"
    puts "-" * 40
  end

rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
ensure
  client.cleanup if client.respond_to?(:cleanup)
  FileUtils.rm_rf(WORK_DIR) if defined?(WORK_DIR) && File.exist?(WORK_DIR)
  puts "\nCleaned up MCP client and temp directory."
end
