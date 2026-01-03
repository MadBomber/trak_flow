# frozen_string_literal: true

module TrakFlow
  module Models
    # Represents a dependency relationship between two issues
    # Types:
    #   - blocks: Hard dependency - target cannot proceed until source is closed
    #   - related: Soft link - informational only
    #   - parent-child: Hierarchical relationship
    #   - discovered-from: Traceability link to origin
    class Dependency
      attr_accessor :id, :source_id, :target_id, :type, :created_at

      VALID_TYPES = TrakFlow::DEPENDENCY_TYPES

      # Blocking dependency types affect ready-work calculations
      BLOCKING_TYPES = %w[blocks parent-child].freeze

      def initialize(attrs = {})
        @id = attrs[:id] || SecureRandom.uuid
        @source_id = attrs[:source_id]
        @target_id = attrs[:target_id]
        @type = attrs[:type] || "blocks"
        @created_at = attrs[:created_at] || Time.now.utc
      end

      def valid?
        errors.empty?
      end

      def errors
        errs = []
        errs << "Source ID is required" if source_id.nil? || source_id.strip.empty?
        errs << "Target ID is required" if target_id.nil? || target_id.strip.empty?
        errs << "Invalid type: #{type}" unless VALID_TYPES.include?(type)
        errs << "Self-referential dependency not allowed" if source_id == target_id
        errs
      end

      def validate!
        raise ValidationError, errors.join(", ") unless valid?
      end

      def blocking?
        BLOCKING_TYPES.include?(type)
      end

      def blocks?
        type == "blocks"
      end

      def parent_child?
        type == "parent-child"
      end

      def related?
        type == "related"
      end

      def discovered_from?
        type == "discovered-from"
      end

      def to_h
        {
          id: id,
          source_id: source_id,
          target_id: target_id,
          type: type,
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
            source_id: hash[:source_id],
            target_id: hash[:target_id],
            type: hash[:type],
            created_at: TimeParser.parse(hash[:created_at])
          )
        end

        def from_json(json_string)
          from_hash(Oj.load(json_string, mode: :compat, symbol_keys: true))
        end
      end
    end
  end
end
