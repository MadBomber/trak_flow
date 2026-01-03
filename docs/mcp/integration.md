# MCP Integration Guide

This guide covers integrating TrakFlow's MCP server with various AI applications and development tools.

## Claude Desktop

### Configuration

Add TrakFlow to your Claude Desktop configuration file:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "trak_flow": {
      "command": "tf",
      "args": ["mcp", "start"],
      "cwd": "/path/to/your/project"
    }
  }
}
```

### Usage

Once configured, Claude can:

- View your tasks: "What tasks are currently open?"
- Create tasks: "Create a task to fix the login bug"
- Update status: "Mark task tf-abc123 as in progress"
- Find work: "What should I work on next?"

## VS Code / Cursor

### With MCP Extension

If using an MCP-enabled extension:

```json
{
  "mcp.servers": {
    "trak_flow": {
      "command": "tf",
      "args": ["mcp", "start"],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

### With Continue.dev

Add to your `.continue/config.json`:

```json
{
  "mcpServers": [
    {
      "name": "trak_flow",
      "command": "tf",
      "args": ["mcp", "start"]
    }
  ]
}
```

## Ruby Applications

### Using ruby_llm-mcp

```ruby
require 'ruby_llm'
require 'ruby_llm/mcp'

# Connect via STDIO
client = RubyLLM::MCP::Client.new(
  transport_type: :stdio,
  command: ["tf", "mcp", "start"],
  working_dir: "/path/to/project"
)

# List available tools
client.tools.each do |tool|
  puts "#{tool.name}: #{tool.description}"
end

# Create a task
create_tool = client.tool("task_create")
result = create_tool.execute(
  title: "Implement feature",
  type: "feature",
  priority: 1
)

puts "Created task: #{result['task']['id']}"

# Get ready tasks
ready_tool = client.tool("ready_tasks")
ready = ready_tool.execute
puts "Ready to work on: #{ready['tasks'].map { |t| t['title'] }}"
```

### Using HTTP Transport

```ruby
require 'ruby_llm/mcp'

# Connect via HTTP/SSE
client = RubyLLM::MCP::Client.new(
  transport_type: :sse,
  url: "http://localhost:9292/sse"
)

# Same API as STDIO
tools = client.tools
resources = client.resources
```

## Python Applications

### Using mcp Package

```python
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    server_params = StdioServerParameters(
        command="tf",
        args=["mcp", "start"],
        cwd="/path/to/project"
    )

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            # Initialize
            await session.initialize()

            # List tools
            tools = await session.list_tools()
            for tool in tools.tools:
                print(f"{tool.name}: {tool.description}")

            # Create a task
            result = await session.call_tool(
                "task_create",
                {"title": "Task from Python", "priority": 1}
            )
            print(result)

asyncio.run(main())
```

## JavaScript/TypeScript

### Using @modelcontextprotocol/sdk

```typescript
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const transport = new StdioClientTransport({
  command: 'tf',
  args: ['mcp', 'start'],
  cwd: '/path/to/project'
});

const client = new Client({
  name: 'my-app',
  version: '1.0.0'
}, {
  capabilities: {}
});

await client.connect(transport);

// List tools
const { tools } = await client.listTools();
console.log('Available tools:', tools.map(t => t.name));

// Create a task
const result = await client.callTool('task_create', {
  title: 'Task from JavaScript',
  type: 'feature'
});
console.log('Created:', result);
```

## HTTP API (Direct)

For applications that can't use MCP directly, start the HTTP server:

```bash
tf mcp start --http --port 9292
```

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/sse` | GET | SSE connection for MCP messages |
| `/messages` | POST | Send MCP request |

### Example with curl

```bash
# Initialize session (returns session ID in SSE stream)
curl -N http://localhost:9292/sse &

# Send a tool call
curl -X POST http://localhost:9292/messages \
  -H "Content-Type: application/json" \
  -d '{
    "method": "tools/call",
    "params": {
      "name": "task_list",
      "arguments": {"status": "open"}
    }
  }'
```

## Custom Integration

### Starting the Server Programmatically

```ruby
require 'trak_flow/mcp'

# Create server with custom configuration
server = TrakFlow::Mcp::Server.new(
  db_path: "/custom/path/trak_flow.db",
  jsonl_path: "/custom/path/issues.jsonl"
)

# STDIO mode
server.run

# Or HTTP mode
server.run_http(
  port: 9292,
  host: "0.0.0.0"
)
```

### Adding Custom Tools

```ruby
require 'trak_flow/mcp'

server = TrakFlow::Mcp::Server.new

# Add a custom tool
server.add_tool(
  name: "my_custom_tool",
  description: "Does something custom",
  parameters: {
    param1: { type: "string", required: true }
  }
) do |params|
  # Tool implementation
  { result: "Custom result for #{params[:param1]}" }
end

server.run
```

## Best Practices

### Performance

1. **Reuse connections** - Don't create new clients for each request
2. **Use STDIO for local** - Lower overhead than HTTP
3. **Cache resource data** - Resources are snapshots, cache appropriately

### Error Handling

```ruby
begin
  result = tool.execute(title: "New task")
rescue RubyLLM::MCP::ToolError => e
  puts "Tool error: #{e.message}"
rescue RubyLLM::MCP::ConnectionError => e
  puts "Connection lost: #{e.message}"
end
```

### Concurrency

The MCP server handles concurrent requests, but consider:

1. **SQLite limitations** - Write operations are serialized
2. **JSONL sync** - Writes are atomic but sequential
3. **Long operations** - Consider timeouts for complex queries

### Security

1. **Local only by default** - HTTP binds to 127.0.0.1
2. **No auth built-in** - Add authentication at network layer
3. **Read project data only** - Server can't access arbitrary files
