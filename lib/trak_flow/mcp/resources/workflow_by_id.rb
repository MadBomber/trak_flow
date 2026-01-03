# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Resources
      class WorkflowById < BaseResource
        uri "trak_flow://workflows/{id}"
        resource_name "Workflow by ID"
        description "Get a Workflow with its tasks"
        mime_type "application/json"

        def content
          self.class.with_database do |db|
            workflow = db.find_task!(params[:id])
            tasks = db.find_workflow_tasks(workflow.id)

            result = {
              workflow: workflow.to_h,
              tasks: tasks.map(&:to_h)
            }
            Oj.dump(result, mode: :compat, indent: 2)
          end
        end
      end
    end
  end
end
