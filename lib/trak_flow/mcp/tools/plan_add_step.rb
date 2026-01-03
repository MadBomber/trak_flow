# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class PlanAddStep < BaseTool
        tool_name "plan_add_step"
        description "Add a step (child task) to a Plan"

        arguments do
          required(:plan_id).filled(:string).description("Plan ID to add step to")
          required(:title).filled(:string).description("Step title")
          optional(:description).filled(:string).description("Step description")
          optional(:type).filled(:string).description("Task type (default: task)")
          optional(:priority).filled(:integer).description("Priority 0-4 (default: 2)")
        end

        def call(plan_id:, title:, description: nil, type: "task", priority: 2)
          self.class.with_database do |db|
            plan = db.find_task!(plan_id)
            raise TrakFlow::Error, "#{plan_id} is not a Plan" unless plan.plan?

            task = db.create_child_task(plan_id, {
              title: title,
              description: description || "",
              type: type,
              priority: priority
            })
            task.to_h
          end
        end
      end
    end
  end
end
