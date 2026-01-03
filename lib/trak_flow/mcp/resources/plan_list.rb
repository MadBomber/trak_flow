# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Resources
      class PlanList < BaseResource
        uri "trak_flow://plans"
        resource_name "Plan List"
        description "List of all Plans (workflow blueprints)"
        mime_type "application/json"

        def content
          self.class.with_database do |db|
            plans = db.find_plans
            Oj.dump(plans.map(&:to_h), mode: :compat, indent: 2)
          end
        end
      end
    end
  end
end
