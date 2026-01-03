# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Resources
      class TaskList < BaseResource
        uri "trak_flow://tasks"
        resource_name "Task List"
        description "List of all tasks with their status and priority"
        mime_type "application/json"

        def content
          self.class.with_database do |db|
            tasks = db.list_tasks({})
            Oj.dump(tasks.map(&:to_h), mode: :compat, indent: 2)
          end
        end
      end
    end
  end
end
