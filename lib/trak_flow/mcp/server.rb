# frozen_string_literal: true

require "fast_mcp"
require "puma"
require "puma/configuration"
require "rack"
require "rackup"

module TrakFlow
  module Mcp
    class Server
      attr_reader :name, :version, :mcp_server

      def initialize(name: "trak_flow", version: TrakFlow::VERSION)
        @name = name
        @version = version
        @mcp_server = FastMcp::Server.new(name: name, version: version)
        register_tools
        register_resources
      end

      def start_stdio
        # Use warn (stderr) not puts (stdout) - stdout is for MCP protocol
        warn "Starting TrakFlow MCP Server (stdio transport)..."
        mcp_server.start
      end

      def start_http(port: nil)
        port ||= TrakFlow.config.mcp.port
        puts "Starting TrakFlow MCP Server (HTTP transport on port #{port})..."

        rack_app = create_rack_app

        # Configure Puma (supports rack.hijack for SSE)
        puma_config = Puma::Configuration.new do |config|
          config.bind "tcp://0.0.0.0:#{port}"
          config.threads 1, 5
          config.workers 0
          config.quiet
          config.app rack_app
        end

        launcher = Puma::Launcher.new(puma_config)

        trap("INT") { launcher.stop }
        trap("TERM") { launcher.stop }

        launcher.run
      end

      def start_both(http_port: nil)
        http_port ||= TrakFlow.config.mcp.port
        puts "Starting TrakFlow MCP Server (dual transport)..."
        puts "  - HTTP: port #{http_port}"
        puts "  - STDIO: reading from stdin"

        # Start HTTP in a thread
        http_thread = Thread.new do
          start_http_server(http_port)
        end

        # Run STDIO in main thread (blocking)
        mcp_server.start

        http_thread.join
      end

      private

      def create_rack_app
        server = mcp_server
        Rack::Builder.new do
          use FastMcp::Transports::RackTransport, server
          run ->(_env) { [404, { "Content-Type" => "text/plain" }, ["TrakFlow MCP Server - Use /mcp/sse for SSE transport"]] }
        end.to_app
      end

      def start_http_server(port)
        rack_app = create_rack_app

        # Configure Puma (supports rack.hijack for SSE)
        puma_config = Puma::Configuration.new do |config|
          config.bind "tcp://0.0.0.0:#{port}"
          config.threads 1, 5
          config.workers 0
          config.quiet
          config.app rack_app
        end

        launcher = Puma::Launcher.new(puma_config)

        trap("INT") { launcher.stop }
        trap("TERM") { launcher.stop }

        launcher.run
      end

      def register_tools
        # Task management tools
        mcp_server.register_tool(Tools::TaskCreate)
        mcp_server.register_tool(Tools::TaskUpdate)
        mcp_server.register_tool(Tools::TaskClose)
        mcp_server.register_tool(Tools::TaskStart)
        mcp_server.register_tool(Tools::TaskBlock)
        mcp_server.register_tool(Tools::TaskDefer)

        # Plan/Workflow tools
        mcp_server.register_tool(Tools::PlanCreate)
        mcp_server.register_tool(Tools::PlanAddStep)
        mcp_server.register_tool(Tools::PlanStart)
        mcp_server.register_tool(Tools::PlanRun)
        mcp_server.register_tool(Tools::WorkflowDiscard)
        mcp_server.register_tool(Tools::WorkflowSummarize)

        # Dependency tools
        mcp_server.register_tool(Tools::DepAdd)
        mcp_server.register_tool(Tools::DepRemove)

        # Label tools
        mcp_server.register_tool(Tools::LabelAdd)
        mcp_server.register_tool(Tools::LabelRemove)

        # Comment tool
        mcp_server.register_tool(Tools::CommentAdd)
      end

      def register_resources
        mcp_server.register_resource(Resources::TaskList)
        mcp_server.register_resource(Resources::TaskById)
        mcp_server.register_resource(Resources::TaskNext)
        mcp_server.register_resource(Resources::PlanList)
        mcp_server.register_resource(Resources::PlanById)
        mcp_server.register_resource(Resources::WorkflowList)
        mcp_server.register_resource(Resources::WorkflowById)
        mcp_server.register_resource(Resources::LabelList)
        mcp_server.register_resource(Resources::DependencyGraph)
      end
    end
  end
end
