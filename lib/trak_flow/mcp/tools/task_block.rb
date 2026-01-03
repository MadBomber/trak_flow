# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class TaskBlock < BaseTool
        tool_name "task_block"
        description "Mark a task as blocked"

        arguments do
          required(:id).filled(:string).description("Task ID to block")
          optional(:reason).filled(:string).description("Reason for blocking")
        end

        def call(id:, reason: nil)
          self.class.with_database do |db|
            task = db.find_task!(id)
            task.status = "blocked"
            task.append_trace("BLOCKED", reason) if reason
            db.update_task(task)
            task.to_h
          end
        end
      end
    end
  end
end
