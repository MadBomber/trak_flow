# frozen_string_literal: true

require "fast_mcp"

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

      def start_http(port: nil, handler: nil)
        require_http_transport_gems
        port ||= TrakFlow.config.mcp.port
        puts "Starting TrakFlow MCP Server (HTTP transport on port #{port})..."

        start_http_server(port, handler)
      end

      def start_both(http_port: nil, handler: nil)
        require_http_transport_gems
        http_port ||= TrakFlow.config.mcp.port
        puts "Starting TrakFlow MCP Server (dual transport)..."
        puts "  - HTTP: port #{http_port}"
        puts "  - STDIO: reading from stdin"

        # Start HTTP in a thread
        http_thread = Thread.new do
          start_http_server(http_port, handler)
        end

        # Run STDIO in main thread (blocking)
        mcp_server.start

        http_thread.join
      end

      # The MCP transport as a plain Rack application. Public so a host app
      # that already runs its own Rack server can mount it there instead of
      # letting trak_flow boot a second server:
      #
      #   # config.ru of the host app
      #   map "/mcp" do
      #     run TrakFlow::Mcp::Server.new.rack_app
      #   end
      #
      # The host's server must support rack.hijack for SSE (Puma, Falcon,
      # WEBrick, iodine all do).
      def rack_app
        require "rack"

        server = mcp_server
        Rack::Builder.new do
          use FastMcp::Transports::RackTransport, server
          run ->(_env) { [404, { "Content-Type" => "text/plain" }, ["TrakFlow MCP Server - Use /mcp/sse for SSE transport"]] }
        end.to_app
      end

      # The Rack server that will run the HTTP transport, resolved through
      # the generic Rackup handler interface so any registered server works.
      # Priority: the explicit argument, then TrakFlow.config.mcp.handler
      # (or the TF_MCP__HANDLER env var), then Rackup's default lookup —
      # which picks a server already in the bundle (puma, falcon, webrick).
      def http_handler(handler_name = nil)
        handler_name ||= TrakFlow.config.mcp.handler
        handler_name ? Rackup::Handler.get(handler_name) : Rackup::Handler.default
      rescue LoadError, NameError => e
        raise LoadError,
              "No usable Rack server#{" for handler '#{handler_name}'" if handler_name} found in the bundle. " \
              'Add one that supports rack.hijack — e.g. `gem "puma"` — to your Gemfile. ' \
              "(#{e.message})"
      end

      # Loads the gems the HTTP transport needs. They are optional
      # dependencies — deliberately NOT in the gemspec, so consumers that
      # only use the models/storage API (or the stdio transport) don't
      # carry HTTP machinery. The Rack *server* is the host application's
      # choice: any bundled server registered with Rackup will do.
      def require_http_transport_gems
        require "rack"
        require "rackup"
      rescue LoadError => e
        raise LoadError,
              "TrakFlow's MCP HTTP transport needs the optional rackup gem plus a Rack " \
              'server that supports rack.hijack. Add `gem "rackup"` — and `gem "puma"` ' \
              "if your app doesn't already bundle a server — to your Gemfile. (#{e.message})"
      end

      private

      def start_http_server(port, handler_name = nil)
        http_handler(handler_name).run(rack_app, Host: "0.0.0.0", Port: port)
      end

      # Every tool the MCP server exposes, grouped by concern.
      TOOLS = [
        # Task management
        Tools::TaskCreate, Tools::TaskUpdate, Tools::TaskClose,
        Tools::TaskStart, Tools::TaskBlock, Tools::TaskDefer,
        # Plan/Workflow
        Tools::PlanCreate, Tools::PlanAddStep, Tools::PlanStart,
        Tools::PlanRun, Tools::WorkflowDiscard, Tools::WorkflowSummarize,
        # Dependencies
        Tools::DepAdd, Tools::DepRemove,
        # Labels
        Tools::LabelAdd, Tools::LabelRemove,
        # Comments
        Tools::CommentAdd
      ].freeze

      RESOURCES = [
        Resources::TaskList, Resources::TaskById, Resources::TaskNext,
        Resources::PlanList, Resources::PlanById,
        Resources::WorkflowList, Resources::WorkflowById,
        Resources::LabelList, Resources::DependencyGraph
      ].freeze

      private_constant :TOOLS, :RESOURCES

      def register_tools
        TOOLS.each { |tool| mcp_server.register_tool(tool) }
      end

      def register_resources
        RESOURCES.each { |resource| mcp_server.register_resource(resource) }
      end
    end
  end
end
