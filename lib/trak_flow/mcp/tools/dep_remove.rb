# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class DepRemove < BaseTool
        tool_name "dep_remove"
        description "Remove a dependency between two tasks"

        arguments do
          required(:source_id).filled(:string).description("Source task ID")
          required(:target_id).filled(:string).description("Target task ID")
        end

        def call(source_id:, target_id:)
          self.class.with_database do |db|
            db.remove_dependency(source_id, target_id)

            { source_id: source_id, target_id: target_id, removed: true }
          end
        end
      end
    end
  end
end
