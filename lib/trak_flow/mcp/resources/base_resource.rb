# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Resources
      class BaseResource < FastMcp::Resource
        class << self
          def with_database
            TrakFlow.ensure_initialized!

            db = Storage::Database.new
            db.connect

            jsonl = Storage::Jsonl.new
            jsonl.import(db) if jsonl.exists?

            yield db
          ensure
            db&.close
          end
        end
      end
    end
  end
end
