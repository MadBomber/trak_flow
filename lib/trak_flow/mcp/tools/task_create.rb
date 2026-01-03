# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class TaskCreate < BaseTool
        tool_name "task_create"
        description "Create a new task with title, type, and priority"

        arguments do
          required(:title).filled(:string).description("Task title")
          optional(:type).filled(:string).description("Task type: bug, feature, task, epic, chore (default: task)")
          optional(:priority).filled(:integer).description("Priority 0-4: 0=critical, 4=backlog (default: 2)")
          optional(:description).filled(:string).description("Task description")
          optional(:assignee).filled(:string).description("Assignee name")
          optional(:parent_id).filled(:string).description("Parent task ID for creating child tasks")
          optional(:labels).array(:string).description("Labels to add")
        end

        def call(title:, type: "task", priority: 2, description: nil, assignee: nil, parent_id: nil, labels: [])
          self.class.with_database do |db|
            task = if parent_id
                db.create_child_task(parent_id, {
                  title: title,
                  description: description,
                  type: type,
                  priority: priority,
                  assignee: assignee
                })
              else
                new_task = Models::Task.new(
                  title: title,
                  description: description,
                  type: type,
                  priority: priority,
                  assignee: assignee
                )
                db.create_task(new_task)
              end

            labels.each do |label_name|
              db.add_label(Models::Label.new(task_id: task.id, name: label_name))
            end

            task.to_h
          end
        end
      end
    end
  end
end
