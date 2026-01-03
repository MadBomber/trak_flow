# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class BaseTool < FastMcp::Tool
        class << self
          def with_database
            TrakFlow.ensure_initialized!

            db = Storage::Database.new
            db.connect

            jsonl = Storage::Jsonl.new
            jsonl.import(db) if jsonl.exists?

            result = yield db

            jsonl.export(db) if db.dirty?

            result
          ensure
            db&.close
          end
        end
      end
    end
  end
end
