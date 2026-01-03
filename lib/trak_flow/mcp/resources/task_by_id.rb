# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Resources
      class TaskById < BaseResource
        uri "trak_flow://tasks/{id}"
        resource_name "Task by ID"
        description "Get a specific task by its ID, including labels, dependencies, and comments"
        mime_type "application/json"

        def content
          self.class.with_database do |db|
            task = db.find_task!(params[:id])
            labels = db.find_labels(task.id)
            deps = db.find_dependencies(task.id)
            comments = db.find_comments(task.id)

            result = {
              task: task.to_h,
              labels: labels.map(&:name),
              dependencies: deps.map(&:to_h),
              comments: comments.map(&:to_h)
            }
            Oj.dump(result, mode: :compat, indent: 2)
          end
        end
      end
    end
  end
end
