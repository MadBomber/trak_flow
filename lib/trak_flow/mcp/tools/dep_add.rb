# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class DepAdd < BaseTool
        tool_name "dep_add"
        description "Add a dependency between two tasks"

        arguments do
          required(:source_id).filled(:string).description("Source task ID")
          required(:target_id).filled(:string).description("Target task ID")
          optional(:type).filled(:string).description("Dependency type: blocks, related, parent-child, discovered-from (default: blocks)")
        end

        def call(source_id:, target_id:, type: "blocks")
          self.class.with_database do |db|
            db.find_task!(source_id)
            db.find_task!(target_id)

            dep = Models::Dependency.new(
              source_id: source_id,
              target_id: target_id,
              type: type
            )
            db.add_dependency(dep)

            { source_id: source_id, target_id: target_id, type: type, success: true }
          end
        end
      end
    end
  end
end
