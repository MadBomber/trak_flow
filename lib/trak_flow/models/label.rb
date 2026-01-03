# frozen_string_literal: true

module TrakFlow
  module Models
    # Represents a label attached to a task
    # Labels provide flexible, multi-dimensional categorization beyond
    # structured fields like status, priority, and type
    class Label
      attr_accessor :id, :task_id, :name, :created_at

      def initialize(attrs = {})
        @id = attrs[:id] || SecureRandom.uuid
        @task_id = attrs[:task_id]
        @name = attrs[:name]
        @created_at = attrs[:created_at] || Time.now.utc
      end

      def valid?
        errors.empty?
      end

      def errors
        errs = []
        errs << "Task ID is required" if task_id.nil? || task_id.to_s.strip.empty?
        errs << "Name is required" if name.nil? || name.strip.empty?
        errs << "Invalid label name" unless valid_name?
        errs
      end

      def validate!
        raise ValidationError, errors.join(", ") unless valid?
      end

      # Labels can use dimension:value format for state caching
      def dimension
        return nil unless name&.include?(":")

        name.split(":").first
      end

      def value
        return name unless name&.include?(":")

        name.split(":", 2).last
      end

      def state_label?
        name&.include?(":")
      end

      def to_h
        {
          id: id,
          task_id: task_id,
          name: name,
          created_at: created_at&.iso8601
        }.compact
      end

      def to_json(*args)
        Oj.dump(to_h, mode: :compat)
      end

      class << self
        def from_hash(hash)
          hash = hash.transform_keys(&:to_sym)
          new(
            id: hash[:id],
            task_id: hash[:task_id],
            name: hash[:name],
            created_at: TimeParser.parse(hash[:created_at])
          )
        end

        def from_json(json_string)
          from_hash(Oj.load(json_string, mode: :compat, symbol_keys: true))
        end
      end

      private

      def valid_name?
        return false if name.nil?

        # Allow alphanumeric, hyphens, underscores, and colons (for state labels)
        name.match?(/^[a-zA-Z0-9_:-]+$/)
      end
    end
  end
end
