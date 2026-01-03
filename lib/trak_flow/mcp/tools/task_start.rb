# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class TaskStart < BaseTool
        tool_name "task_start"
        description "Start working on a task (set status to in_progress)"

        arguments do
          required(:id).filled(:string).description("Task ID to start")
        end

        def call(id:)
          self.class.with_database do |db|
            task = db.find_task!(id)
            task.status = "in_progress"
            db.update_task(task)
            task.to_h
          end
        end
      end
    end
  end
end
