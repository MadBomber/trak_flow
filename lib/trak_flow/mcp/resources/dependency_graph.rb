# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Resources
      class DependencyGraph < BaseResource
        uri "trak_flow://graph/dependencies"
        resource_name "Dependency Graph"
        description "Full dependency graph of all tasks"
        mime_type "application/json"

        def content
          self.class.with_database do |db|
            tasks = db.list_tasks

            result = {
              nodes: tasks.map { |t| { id: t.id, title: t.title, status: t.status } },
              edges: edges_for(db, tasks)
            }
            Oj.dump(result, mode: :compat, indent: 2)
          end
        end

        private

        def edges_for(db, tasks)
          tasks.flat_map do |task|
            db.find_dependencies(task.id, direction: :outgoing)
              .map { |dep| { source: dep.source_id, target: dep.target_id, type: dep.type } }
          end
        end
      end
    end
  end
end
