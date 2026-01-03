# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "tmpdir"

# Helper module for CLI tests
module CLITestHelper
  # Run a CLI command and capture output
  def run_cli(*args)
    stdout, stderr = capture_io do
      TrakFlow::CLI.start(args)
    end
    CLIResult.new(stdout, stderr)
  rescue SystemExit => e
    CLIResult.new(stdout || "", stderr || "", e.status)
  end

  # Run CLI command expecting JSON output
  def run_cli_json(*args)
    result = run_cli(*args, "-j")
    Oj.load(result.stdout, symbol_keys: false)
  end

  # Set up a temporary TrakFlow directory for testing
  def setup_temp_trak_flow
    @original_dir = Dir.pwd
    @temp_dir = Dir.mktmpdir("trak_flow_test")
    Dir.chdir(@temp_dir)

    # Reset TrakFlow to use the temp directory
    TrakFlow.instance_variable_set(:@root, nil)
    TrakFlow.instance_variable_set(:@trak_flow_dir, nil)
    TrakFlow.reset_config!
  end

  # Clean up temporary directory
  def teardown_temp_trak_flow
    Dir.chdir(@original_dir) if @original_dir
    FileUtils.rm_rf(@temp_dir) if @temp_dir
    TrakFlow.instance_variable_set(:@root, nil)
    TrakFlow.instance_variable_set(:@trak_flow_dir, nil)
    TrakFlow.reset_config!
  end

  # Initialize TrakFlow in the temp directory
  def init_trak_flow
    run_cli("init")
  end

  # Create a task and return its ID
  def create_task(title, **options)
    args = ["create", title]
    args += ["-t", options[:type]] if options[:type]
    args += ["-p", options[:priority].to_s] if options[:priority]
    args += ["-d", options[:description]] if options[:description]
    args += ["-a", options[:assignee]] if options[:assignee]
    args += ["--plan"] if options[:plan]
    args += ["--ephemeral"] if options[:ephemeral]
    args += ["--parent", options[:parent]] if options[:parent]
    args << "-j"

    result = Oj.load(run_cli(*args).stdout, symbol_keys: false)
    result["id"]
  end

  # Simple result object for CLI output
  class CLIResult
    attr_reader :stdout, :stderr, :exit_status

    def initialize(stdout, stderr, exit_status = 0)
      @stdout = stdout
      @stderr = stderr
      @exit_status = exit_status
    end

    def success?
      @exit_status == 0
    end

    def output
      @stdout
    end
  end
end
