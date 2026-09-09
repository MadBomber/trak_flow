# frozen_string_literal: true

require_relative "mcp_test_helper"

class MCPServerTest < Minitest::Test
  include MCPTestHelper

  def setup
    setup_mcp_test
  end

  def teardown
    teardown_mcp_test
  end

  def test_server_initialization
    server = TrakFlow::Mcp::Server.new

    assert_equal "trak_flow", server.name
    assert_equal TrakFlow::VERSION, server.version
    refute_nil server.mcp_server
  end

  def test_server_custom_name_and_version
    server = TrakFlow::Mcp::Server.new(name: "custom", version: "2.0.0")

    assert_equal "custom", server.name
    assert_equal "2.0.0", server.version
  end

  def test_server_has_mcp_server
    server = TrakFlow::Mcp::Server.new

    # Verify the underlying FastMcp::Server is created and configured
    assert_instance_of FastMcp::Server, server.mcp_server
  end

  def test_tool_classes_are_defined
    # Verify all tool classes exist and inherit from BaseTool
    tool_classes = [
      TrakFlow::Mcp::Tools::TaskCreate,
      TrakFlow::Mcp::Tools::TaskUpdate,
      TrakFlow::Mcp::Tools::TaskClose,
      TrakFlow::Mcp::Tools::TaskStart,
      TrakFlow::Mcp::Tools::TaskBlock,
      TrakFlow::Mcp::Tools::TaskDefer,
      TrakFlow::Mcp::Tools::PlanCreate,
      TrakFlow::Mcp::Tools::PlanAddStep,
      TrakFlow::Mcp::Tools::PlanStart,
      TrakFlow::Mcp::Tools::PlanRun,
      TrakFlow::Mcp::Tools::WorkflowDiscard,
      TrakFlow::Mcp::Tools::WorkflowSummarize,
      TrakFlow::Mcp::Tools::DepAdd,
      TrakFlow::Mcp::Tools::DepRemove,
      TrakFlow::Mcp::Tools::LabelAdd,
      TrakFlow::Mcp::Tools::LabelRemove,
      TrakFlow::Mcp::Tools::CommentAdd
    ]

    tool_classes.each do |klass|
      assert klass < TrakFlow::Mcp::Tools::BaseTool,
             "Expected #{klass} to inherit from BaseTool"
    end
  end

  def test_resource_classes_are_defined
    # Verify all resource classes exist and inherit from BaseResource
    resource_classes = [
      TrakFlow::Mcp::Resources::TaskList,
      TrakFlow::Mcp::Resources::TaskById,
      TrakFlow::Mcp::Resources::TaskNext,
      TrakFlow::Mcp::Resources::PlanList,
      TrakFlow::Mcp::Resources::PlanById,
      TrakFlow::Mcp::Resources::WorkflowList,
      TrakFlow::Mcp::Resources::WorkflowById,
      TrakFlow::Mcp::Resources::LabelList,
      TrakFlow::Mcp::Resources::DependencyGraph
    ]

    resource_classes.each do |klass|
      assert klass < TrakFlow::Mcp::Resources::BaseResource,
             "Expected #{klass} to inherit from BaseResource"
    end
  end

  def test_rack_app_is_a_rack_application
    server = TrakFlow::Mcp::Server.new
    app = server.rack_app

    assert_respond_to app, :call
  end

  def test_rack_app_returns_404_for_unknown_paths
    require "rack"
    server = TrakFlow::Mcp::Server.new

    status, _headers, _body = server.rack_app.call(Rack::MockRequest.env_for("/nope"))

    assert_equal 404, status
  end

  def test_http_handler_resolves_explicit_name
    require "rackup"
    server = TrakFlow::Mcp::Server.new

    handler = server.http_handler("puma")

    assert_respond_to handler, :run
  end

  def test_http_handler_defaults_to_bundled_server
    require "rackup"
    server = TrakFlow::Mcp::Server.new

    handler = server.http_handler

    assert_respond_to handler, :run
  end

  def test_http_handler_raises_helpful_error_for_unknown_server
    require "rackup"
    server = TrakFlow::Mcp::Server.new

    error = assert_raises(LoadError) { server.http_handler("no_such_server") }

    assert_match(/no_such_server/, error.message)
    assert_match(/puma/, error.message)
  end
end
