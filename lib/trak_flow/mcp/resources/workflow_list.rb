# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Resources
      class WorkflowList < BaseResource
        uri "trak_flow://workflows"
        resource_name "Workflow List"
        description "List of all Workflows (running instances of Plans)"
        mime_type "application/json"

        def content
          self.class.with_database do |db|
            workflows = db.find_workflows
            Oj.dump(workflows.map(&:to_h), mode: :compat, indent: 2)
          end
        end
      end
    end
  end
end
