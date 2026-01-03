# frozen_string_literal: true

module TrakFlow
  # Shared time parsing utilities for model deserialization
  module TimeParser
    def self.parse(value)
      return nil if value.nil?
      return value if value.is_a?(Time)

      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end
end
