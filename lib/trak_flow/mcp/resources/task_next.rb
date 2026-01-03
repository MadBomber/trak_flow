# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Resources
      class TaskNext < BaseResource
        uri "trak_flow://tasks/next"
        resource_name "Next Actionable Task"
        description "Get the next actionable task (highest priority with no blockers)"
        mime_type "application/json"

        def content
          self.class.with_database do |db|
            tasks = db.ready_tasks
            next_task = tasks.first

            if next_task
              labels = db.find_labels(next_task.id)
              result = { task: next_task.to_h, labels: labels.map(&:name) }
            else
              result = { task: nil, message: "No ready tasks found" }
            end

            Oj.dump(result, mode: :compat, indent: 2)
          end
        end
      end
    end
  end
end
