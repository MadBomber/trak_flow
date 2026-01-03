#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo: TrakFlow MCP Server with HTTP Transport
#
# This example shows how to connect to the TrakFlow MCP server
# using HTTP/SSE transport with the ruby_llm and ruby_llm-mcp gems.
#
# The demo demonstrates:
#   - Connecting via HTTP/SSE transport
#   - Listing available tools and resources
#   - Creating a task via MCP tool
#   - Starting and closing the task (showing state changes)
#   - Optionally using an LLM with MCP tools
#
# Prerequisites:
#   - Ollama running: ollama serve
#   - Model available: ollama pull gpt-oss (or set OLLAMA_MODEL env var)
#
# The demo will automatically start the MCP server if not running.
#
# Usage:
#   cd examples/mcp
#   bundle install
#   ruby http_demo.rb

require "bundler/setup"
require "ruby_llm"
require "ruby_llm/mcp"
require "fileutils"
require "socket"
require "tmpdir"

# Configure RubyLLM to use Ollama
RubyLLM.configure do |config|
  config.ollama_api_base = ENV["OLLAMA_API_BASE"] || ENV["OLLAMA_URL"] || "http://localhost:11434/v1"
end

# Model configuration
OLLAMA_MODEL = ENV.fetch("OLLAMA_MODEL", "gpt-oss:latest")

# MCP server HTTP endpoint (default port from TrakFlow config)
MCP_PORT = ENV.fetch("MCP_PORT", "3333").to_i
MCP_HTTP_URL = ENV.fetch("MCP_URL", "http://localhost:#{MCP_PORT}")

# Path to the TrakFlow MCP server executable and project root
PROJECT_ROOT = File.expand_path("../..", __dir__)
TF_MCP_PATH = File.join(PROJECT_ROOT, "bin/tf_mcp")
TF_CLI_PATH = File.join(PROJECT_ROOT, "bin/tf")
GEMFILE_PATH = File.join(PROJECT_ROOT, "Gemfile")

def port_open?(port, host = "127.0.0.1")
  Socket.tcp(host, port, connect_timeout: 1) { true }
rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError
  false
end

def wait_for_server(port, timeout: 10)
  start = Time.now
  until port_open?(port)
    return false if Time.now - start > timeout
    sleep 0.2
  end
  true
end

puts "TrakFlow MCP HTTP Demo"
puts "=" * 40
puts

# Check if server is running, start it if not
server_pid = nil
work_dir = nil

unless port_open?(MCP_PORT)
  puts "MCP server not running on port #{MCP_PORT}. Starting it..."

  # Create a temp directory and initialize TrakFlow there
  work_dir = Dir.mktmpdir("trakflow_mcp_http_demo")
  puts "Working directory: #{work_dir}"

  # Initialize TrakFlow in the temp directory
  Dir.chdir(work_dir) do
    system({ "BUNDLE_GEMFILE" => GEMFILE_PATH }, "bundle", "exec", TF_CLI_PATH, "init", out: File::NULL, err: File::NULL)
  end

  # Start the MCP server in the background
  server_pid = spawn(
    { "BUNDLE_GEMFILE" => GEMFILE_PATH },
    "bundle", "exec", TF_MCP_PATH, "--http", "--port", MCP_PORT.to_s,
    chdir: work_dir,
    out: File::NULL,
    err: File::NULL
  )
  Process.detach(server_pid)

  puts "Started MCP server (PID: #{server_pid})"

  unless wait_for_server(MCP_PORT)
    puts "ERROR: Server failed to start within timeout"
    Process.kill("TERM", server_pid) rescue nil
    FileUtils.rm_rf(work_dir) if work_dir
    exit 1
  end

  puts "MCP server is ready."
else
  puts "MCP server already running on port #{MCP_PORT}"
end

puts
puts "Connecting to: #{MCP_HTTP_URL}"
puts

# Create MCP client with SSE transport (HTTP-based)
client = RubyLLM::MCP.client(
  name: "trakflow",
  transport_type: :sse,
  config: {
    url: "#{MCP_HTTP_URL}/mcp/sse"
  }
)

begin
  # The client connects automatically on creation
  puts "Connected to TrakFlow MCP server via HTTP/SSE..."
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
    title: "Demo task from HTTP",
    description: "Created via MCP HTTP transport demo"
  )

  puts "Result: #{result}"

  # Example: Create a plan
  puts "\n" + "=" * 40
  puts "Creating a plan..."
  puts "-" * 40

  plan_tool = client.tool("plan_create")
  plan_result = plan_tool.execute(
    title: "Example workflow plan",
    description: "A demo plan with steps"
  )
  puts "Plan created: #{plan_result}"

  # Extract the task ID from the creation result
  # result may be a String or object with .to_s
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

rescue Errno::ECONNREFUSED
  puts "Error: Could not connect to MCP server at #{MCP_HTTP_URL}"
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
ensure
  client.cleanup if client.respond_to?(:cleanup)

  # Stop server if we started it
  if server_pid
    Process.kill("TERM", server_pid) rescue nil
    puts "Stopped MCP server (PID: #{server_pid})"
  end

  # Clean up temp directory if we created it
  if work_dir && File.exist?(work_dir)
    FileUtils.rm_rf(work_dir)
    puts "Cleaned up temp directory."
  end

  puts "\nCleaned up MCP client."
end
