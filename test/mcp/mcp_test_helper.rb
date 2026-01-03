# frozen_string_literal: true

require_relative "../test_helper"
require "trak_flow/mcp"

# Helper module for MCP tests
module MCPTestHelper
  def setup_mcp_test
    @original_dir = Dir.pwd
    @temp_dir = Dir.mktmpdir("trak_flow_mcp_test")
    Dir.chdir(@temp_dir)

    TrakFlow.instance_variable_set(:@root, nil)
    TrakFlow.instance_variable_set(:@trak_flow_dir, nil)
    TrakFlow.reset_config!

    init_trak_flow
  end

  def teardown_mcp_test
    Dir.chdir(@original_dir) if @original_dir
    FileUtils.rm_rf(@temp_dir) if @temp_dir
    TrakFlow.instance_variable_set(:@root, nil)
    TrakFlow.instance_variable_set(:@trak_flow_dir, nil)
    TrakFlow.reset_config!
  end

  def init_trak_flow
    trak_flow_dir = File.join(@temp_dir, ".trak_flow")
    FileUtils.mkdir_p(trak_flow_dir)

    # Configure database path to use test directory
    db_path = File.join(trak_flow_dir, "trak_flow.db")
    TrakFlow.config.database.path = db_path

    @db = TrakFlow::Storage::Database.new(db_path)
    @db.connect
  end

  def create_test_task(title, **attrs)
    task = TrakFlow::Models::Task.new(
      title: title,
      type: attrs[:type] || "task",
      priority: attrs[:priority] || 2,
      description: attrs[:description] || "",
      assignee: attrs[:assignee],
      plan: attrs[:plan] || false,
      ephemeral: attrs[:ephemeral] || false
    )
    @db.create_task(task)
    task
  end

  def create_test_plan(title, **attrs)
    create_test_task(title, plan: true, **attrs)
  end
end
