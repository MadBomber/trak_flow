# frozen_string_literal: true

module TrakFlow
  module Models
    # Represents a comment on a task
    class Comment
      attr_accessor :id, :task_id, :author, :body, :created_at, :updated_at

      def initialize(attrs = {})
        @id = attrs[:id] || SecureRandom.uuid
        @task_id = attrs[:task_id]
        @author = attrs[:author] || TrakFlow.config.get("actor")
        @body = attrs[:body]
        @created_at = attrs[:created_at] || Time.now.utc
        @updated_at = attrs[:updated_at] || Time.now.utc
      end

      def valid?
        errors.empty?
      end

      def errors
        errs = []
        errs << "Task ID is required" if task_id.nil? || task_id.to_s.strip.empty?
        errs << "Body is required" if body.nil? || body.strip.empty?
        errs
      end

      def validate!
        raise ValidationError, errors.join(", ") unless valid?
      end

      def touch!
        self.updated_at = Time.now.utc
      end

      def to_h
        {
          id: id,
          task_id: task_id,
          author: author,
          body: body,
          created_at: created_at&.iso8601,
          updated_at: updated_at&.iso8601
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
            author: hash[:author],
            body: hash[:body],
            created_at: TimeParser.parse(hash[:created_at]),
            updated_at: TimeParser.parse(hash[:updated_at])
          )
        end

        def from_json(json_string)
          from_hash(Oj.load(json_string, mode: :compat, symbol_keys: true))
        end
      end
    end
  end
end
