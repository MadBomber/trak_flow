# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class PlanRun < BaseTool
        tool_name "plan_run"
        description "Create an ephemeral Workflow from a Plan (one-shot, garbage collectible)"

        arguments do
          required(:plan_id).filled(:string).description("Plan ID to instantiate")
          optional(:variables).hash.description("Template variables for interpolation")
        end

        def call(plan_id:, variables: {})
          self.class.with_database do |db|
            plan = db.find_task!(plan_id)
            raise TrakFlow::Error, "#{plan_id} is not a Plan" unless plan.plan?

            workflow = Models::Task.new(
              title: interpolate_vars(plan.title, variables),
              description: interpolate_vars(plan.description, variables),
              type: plan.type,
              priority: plan.priority,
              source_plan_id: plan.id,
              ephemeral: true
            )
            db.create_task(workflow)
            workflow.append_trace("INSTANTIATED", "from Plan #{plan.id} (ephemeral)")
            db.update_task(workflow)

            db.find_plan_tasks(plan_id).each do |step|
              db.create_child_task(workflow.id, {
                title: interpolate_vars(step.title, variables),
                description: interpolate_vars(step.description, variables),
                type: step.type,
                priority: step.priority,
                ephemeral: true
              })
            end

            workflow.to_h
          end
        end

        private

        def interpolate_vars(text, vars)
          return text if text.nil? || vars.empty?

          result = text.dup
          vars.each { |key, value| result.gsub!("{{#{key}}}", value.to_s) }
          result
        end
      end
    end
  end
end
