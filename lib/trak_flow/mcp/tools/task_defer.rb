# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class TaskDefer < BaseTool
        tool_name "task_defer"
        description "Defer a task for later"

        arguments do
          required(:id).filled(:string).description("Task ID to defer")
          optional(:reason).filled(:string).description("Reason for deferring")
        end

        def call(id:, reason: nil)
          self.class.with_database do |db|
            task = db.find_task!(id)
            task.status = "deferred"
            task.append_trace("DEFERRED", reason) if reason
            db.update_task(task)
            task.to_h
          end
        end
      end
    end
  end
end
