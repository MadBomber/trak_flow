# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class WorkflowSummarize < BaseTool
        tool_name "workflow_summarize"
        description "Summarize and close a Workflow"

        arguments do
          required(:id).filled(:string).description("Workflow ID to summarize")
          required(:summary).filled(:string).description("Summary text")
        end

        def call(id:, summary:)
          self.class.with_database do |db|
            workflow = db.find_task!(id)

            workflow.notes = "#{workflow.notes}\n\n[Summary]\n#{summary}".strip
            workflow.close!(reason: "summarized")
            db.update_task(workflow)

            db.child_tasks(id).each do |child|
              child.close!(reason: "workflow summarized")
              db.update_task(child)
            end

            workflow.to_h
          end
        end
      end
    end
  end
end
