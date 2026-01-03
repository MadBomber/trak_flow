# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class TaskUpdate < BaseTool
        tool_name "task_update"
        description "Update task attributes (title, priority, status, description, assignee)"

        arguments do
          required(:id).filled(:string).description("Task ID to update")
          optional(:title).filled(:string).description("New title")
          optional(:status).filled(:string).description("New status: open, in_progress, blocked, deferred, closed")
          optional(:priority).filled(:integer).description("New priority 0-4")
          optional(:description).filled(:string).description("New description")
          optional(:assignee).filled(:string).description("New assignee")
        end

        def call(id:, title: nil, status: nil, priority: nil, description: nil, assignee: nil)
          self.class.with_database do |db|
            task = db.find_task!(id)

            task.title = title if title
            task.status = status if status
            task.priority = priority if priority
            task.description = description if description
            task.assignee = assignee if assignee

            db.update_task(task)
            task.to_h
          end
        end
      end
    end
  end
end
