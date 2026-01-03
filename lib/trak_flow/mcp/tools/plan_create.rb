# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class PlanCreate < BaseTool
        tool_name "plan_create"
        description "Create a new Plan (workflow blueprint)"

        arguments do
          required(:title).filled(:string).description("Plan title")
          optional(:description).filled(:string).description("Plan description")
          optional(:type).filled(:string).description("Task type (default: task)")
          optional(:priority).filled(:integer).description("Priority 0-4 (default: 2)")
        end

        def call(title:, description: nil, type: "task", priority: 2)
          self.class.with_database do |db|
            plan = Models::Task.new(
              title: title,
              description: description || "",
              type: type,
              priority: priority,
              plan: true
            )
            db.create_task(plan)
            plan.to_h
          end
        end
      end
    end
  end
end
