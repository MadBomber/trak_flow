# frozen_string_literal: true

require "fast_mcp"

# Tools
require_relative "mcp/tools/base_tool"
require_relative "mcp/tools/task_create"
require_relative "mcp/tools/task_update"
require_relative "mcp/tools/task_close"
require_relative "mcp/tools/task_start"
require_relative "mcp/tools/task_block"
require_relative "mcp/tools/task_defer"
require_relative "mcp/tools/plan_create"
require_relative "mcp/tools/plan_add_step"
require_relative "mcp/tools/plan_start"
require_relative "mcp/tools/plan_run"
require_relative "mcp/tools/workflow_discard"
require_relative "mcp/tools/workflow_summarize"
require_relative "mcp/tools/dep_add"
require_relative "mcp/tools/dep_remove"
require_relative "mcp/tools/label_add"
require_relative "mcp/tools/label_remove"
require_relative "mcp/tools/comment_add"

# Resources
require_relative "mcp/resources/base_resource"
require_relative "mcp/resources/task_list"
require_relative "mcp/resources/task_by_id"
require_relative "mcp/resources/task_next"
require_relative "mcp/resources/plan_list"
require_relative "mcp/resources/plan_by_id"
require_relative "mcp/resources/workflow_list"
require_relative "mcp/resources/workflow_by_id"
require_relative "mcp/resources/label_list"
require_relative "mcp/resources/dependency_graph"

# Server
require_relative "mcp/server"
