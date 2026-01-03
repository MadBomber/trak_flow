# frozen_string_literal: true

module TrakFlow
  module Models
    # Represents a task in the TrakFlow system
    #
    # Tasks serve multiple roles determined by flags:
    # - Plan (blueprint):  task.plan? == true
    # - Workflow:          task.source_plan_id.present? && !task.plan?
    # - Step (conceptual): child Task of a Plan
    # - Work item:         child Task of a Workflow
    #
    # Tasks can be bugs, features, tasks, epics, or chores
    class Task
      attr_accessor :id, :title, :description, :status, :priority, :type,
                    :assignee, :parent_id, :created_at, :updated_at, :closed_at,
                    :content_hash, :plan, :source_plan_id, :ephemeral, :notes

      VALID_STATUSES = TrakFlow::STATUSES
      VALID_PRIORITIES = TrakFlow::PRIORITIES
      VALID_TYPES = TrakFlow::TYPES

      def initialize(attrs = {})
        @id = attrs[:id]
        @title = attrs[:title]
        @description = attrs[:description] || ""
        @status = attrs[:status] || "open"
        @priority = attrs[:priority] || 2
        @type = attrs[:type] || "task"
        @assignee = attrs[:assignee]
        @parent_id = attrs[:parent_id]
        @created_at = attrs[:created_at] || Time.now.utc
        @updated_at = attrs[:updated_at] || Time.now.utc
        @closed_at = attrs[:closed_at]
        @content_hash = attrs[:content_hash]
        @plan = attrs[:plan] || false
        @source_plan_id = attrs[:source_plan_id]
        @ephemeral = attrs[:ephemeral] || false
        @notes = attrs[:notes] || ""
      end

      def valid?
        errors.empty?
      end

      def errors
        errs = []
        errs << "Title is required" if title.nil? || title.strip.empty?
        errs << "Invalid status: #{status}" unless VALID_STATUSES.include?(status)
        errs << "Invalid priority: #{priority}" unless VALID_PRIORITIES.include?(priority)
        errs << "Invalid type: #{type}" unless VALID_TYPES.include?(type)
        errs << "Plans cannot be ephemeral" if plan && ephemeral
        errs << "Plans cannot change status" if plan && status != "open"
        errs << "Plans cannot be derived from other Plans" if plan && source_plan_id
        errs
      end

      def validate!
        raise ValidationError, errors.join(", ") unless valid?
      end

      def open?
        status == "open"
      end

      def closed?
        status == "closed" || status == "tombstone"
      end

      def in_progress?
        status == "in_progress"
      end

      def blocked?
        status == "blocked"
      end

      def epic?
        type == "epic"
      end

      # Plan/Workflow role predicates

      def plan?
        !!plan
      end

      def workflow?
        source_plan_id && !source_plan_id.to_s.empty? && !plan?
      end

      def ephemeral?
        !!ephemeral
      end

      def executable?
        !plan?
      end

      def discardable?
        ephemeral?
      end

      def close!(reason: nil)
        self.status = "closed"
        self.closed_at = Time.now.utc
        self.notes = "#{notes}\n[Closed] #{reason}".strip if reason
        touch!
      end

      def reopen!(reason: nil)
        self.status = "open"
        self.closed_at = nil
        self.notes = "#{notes}\n[Reopened] #{reason}".strip if reason
        touch!
      end

      def touch!
        self.updated_at = Time.now.utc
        update_content_hash!
      end

      def append_trace(action, message)
        timestamp = Time.now.utc.iso8601
        entry = "[#{timestamp}] [#{action}] #{message}"
        self.notes = "#{notes}\n#{entry}".strip
        touch!
      end

      def update_content_hash!
        self.content_hash = IdGenerator.content_hash(to_h.except(:content_hash, :updated_at))
      end

      def to_h
        {
          id: id,
          title: title,
          description: description,
          status: status,
          priority: priority,
          type: type,
          assignee: assignee,
          parent_id: parent_id,
          created_at: created_at&.iso8601,
          updated_at: updated_at&.iso8601,
          closed_at: closed_at&.iso8601,
          content_hash: content_hash,
          plan: plan,
          source_plan_id: source_plan_id,
          ephemeral: ephemeral,
          notes: notes
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
            title: hash[:title],
            description: hash[:description],
            status: hash[:status],
            priority: hash[:priority]&.to_i,
            type: hash[:type],
            assignee: hash[:assignee],
            parent_id: hash[:parent_id],
            created_at: TimeParser.parse(hash[:created_at]),
            updated_at: TimeParser.parse(hash[:updated_at]),
            closed_at: TimeParser.parse(hash[:closed_at]),
            content_hash: hash[:content_hash],
            plan: hash[:plan],
            source_plan_id: hash[:source_plan_id],
            ephemeral: hash[:ephemeral],
            notes: hash[:notes]
          )
        end

        def from_json(json_string)
          from_hash(Oj.load(json_string, mode: :compat, symbol_keys: true))
        end
      end
    end
  end
end
