# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Resources
      class PlanById < BaseResource
        uri "trak_flow://plans/{id}"
        resource_name "Plan by ID"
        description "Get a Plan with its steps (child tasks)"
        mime_type "application/json"

        def content
          self.class.with_database do |db|
            plan = db.find_task!(params[:id])
            steps = db.find_plan_tasks(plan.id)

            result = {
              plan: plan.to_h,
              steps: steps.map(&:to_h)
            }
            Oj.dump(result, mode: :compat, indent: 2)
          end
        end
      end
    end
  end
end
