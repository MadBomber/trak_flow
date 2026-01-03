# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Resources
      class LabelList < BaseResource
        uri "trak_flow://labels"
        resource_name "Label List"
        description "List of all unique labels in the system"
        mime_type "application/json"

        def content
          self.class.with_database do |db|
            labels = db.all_labels
            Oj.dump(labels, mode: :compat, indent: 2)
          end
        end
      end
    end
  end
end
