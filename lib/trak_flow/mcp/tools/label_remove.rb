# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class LabelRemove < BaseTool
        tool_name "label_remove"
        description "Remove a label from a task"

        arguments do
          required(:task_id).filled(:string).description("Task ID")
          required(:name).filled(:string).description("Label name")
        end

        def call(task_id:, name:)
          self.class.with_database do |db|
            db.remove_label(task_id, name)

            { task_id: task_id, label: name, removed: true }
          end
        end
      end
    end
  end
end
