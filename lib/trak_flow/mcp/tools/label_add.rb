# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class LabelAdd < BaseTool
        tool_name "label_add"
        description "Add a label to a task"

        arguments do
          required(:task_id).filled(:string).description("Task ID")
          required(:name).filled(:string).description("Label name")
        end

        def call(task_id:, name:)
          self.class.with_database do |db|
            db.find_task!(task_id)

            label = Models::Label.new(task_id: task_id, name: name)
            db.add_label(label)

            { task_id: task_id, label: name, success: true }
          end
        end
      end
    end
  end
end
