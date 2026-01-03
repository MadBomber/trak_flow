# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class WorkflowDiscard < BaseTool
        tool_name "workflow_discard"
        description "Discard an ephemeral Workflow (deletes it and all its tasks)"

        arguments do
          required(:id).filled(:string).description("Workflow ID to discard")
        end

        def call(id:)
          self.class.with_database do |db|
            workflow = db.find_task!(id)
            raise TrakFlow::Error, "Can only discard ephemeral Workflows" unless workflow.discardable?

            db.child_tasks(id).each { |child| db.delete_task(child.id) }
            db.delete_task(id)

            { discarded: id, success: true }
          end
        end
      end
    end
  end
end
