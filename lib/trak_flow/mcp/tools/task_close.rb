# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class TaskClose < BaseTool
        tool_name "task_close"
        description "Close a task"

        arguments do
          required(:id).filled(:string).description("Task ID to close")
          optional(:reason).filled(:string).description("Reason for closing")
        end

        def call(id:, reason: nil)
          self.class.with_database do |db|
            task = db.find_task!(id)
            task.close!(reason: reason)
            db.update_task(task)
            task.to_h
          end
        end
      end
    end
  end
end
