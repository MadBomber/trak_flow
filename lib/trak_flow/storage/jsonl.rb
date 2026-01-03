# frozen_string_literal: true

module TrakFlow
  module Storage
    # JSONL (JSON Lines) persistence layer for Git integration
    # This is the git-tracked source of truth stored in .trak_flow/tasks.jsonl
    # One JSON entity per line makes diffs readable and merges usually automatic
    class Jsonl
      ENTITY_TYPES = %w[task dependency label comment].freeze

      attr_reader :path

      def initialize(path = nil)
        @path = path || TrakFlow.jsonl_path
      end

      # Export all data from database to JSONL file
      # - Plans are exported (persistent blueprints)
      # - Ephemeral Workflows are NOT exported (temporary only)
      def export(db)
        entities = []

        # Export regular tasks (excluding ephemeral) and include Plans
        db.list_tasks(include_ephemeral: false, include_plans: true, include_tombstones: true).each do |task|
          entities << { type: "task", data: task.to_h }
        end

        db.all_task_ids.each do |task_id|
          db.find_dependencies(task_id, direction: :outgoing).each do |dep|
            entities << { type: "dependency", data: dep.to_h }
          end

          db.find_labels(task_id).each do |label|
            entities << { type: "label", data: label.to_h }
          end

          db.find_comments(task_id).each do |comment|
            entities << { type: "comment", data: comment.to_h }
          end
        end

        write_entities(entities)
        db.mark_clean!
      end

      # Import all data from JSONL file to database
      # @param db [Database] the database to import into
      # @param orphan_handling [String] how to handle orphaned tasks
      # @param error_policy [String] how to handle import errors: "warn", "strict", or "ignore"
      def import(db, orphan_handling: nil, error_policy: nil)
        orphan_handling ||= TrakFlow.config.get("import.orphan_handling")
        error_policy ||= TrakFlow.config.get("import.error_policy") || "warn"

        entities = read_entities
        tasks = []
        dependencies = []
        labels = []
        comments = []
        import_errors = []

        entities.each do |entity|
          case entity[:type]
          when "task"
            tasks << Models::Task.from_hash(entity[:data])
          when "dependency"
            dependencies << Models::Dependency.from_hash(entity[:data])
          when "label"
            labels << Models::Label.from_hash(entity[:data])
          when "comment"
            comments << Models::Comment.from_hash(entity[:data])
          end
        end

        tasks = handle_orphans(tasks, orphan_handling)

        db.import_tasks(tasks)

        import_errors += import_entities(db, :add_dependency, dependencies, error_policy)
        import_errors += import_entities(db, :add_label, labels, error_policy)
        import_errors += import_entities(db, :add_comment, comments, error_policy)

        raise_if_strict_errors(import_errors, error_policy)
      end

      private

      def import_entities(db, method, entities, error_policy)
        errors = []
        entities.each do |entity|
          db.send(method, entity)
        rescue Error => e
          error_info = { entity_type: entity.class.name, error: e.message }
          errors << error_info
          handle_import_error(error_info, error_policy)
        end
        errors
      end

      def handle_import_error(error_info, policy)
        case policy
        when "strict"
          # Errors collected for batch raise
        when "warn"
          debug_me "Warning: Import failed for #{error_info[:entity_type]}: #{error_info[:error]}"
        when "ignore"
          # Silent
        end
      end

      def raise_if_strict_errors(errors, policy)
        return if errors.empty? || policy != "strict"

        messages = errors.map { |e| "#{e[:entity_type]}: #{e[:error]}" }
        raise ValidationError, "Import failed with #{errors.size} error(s):\n  #{messages.join("\n  ")}"
      end

      public

      # Check if JSONL file has changed since last import
      def changed_since?(timestamp)
        return true unless File.exist?(path)

        File.mtime(path) > timestamp
      end

      # Get content hash of the JSONL file
      def content_hash
        return nil unless File.exist?(path)

        Digest::SHA256.hexdigest(File.read(path))[0, 16]
      end

      # Check if file exists
      def exists?
        File.exist?(path)
      end

      # Read raw entities from file
      def read_entities
        return [] unless File.exist?(path)

        entities = []
        File.readlines(path).each_with_index do |line, index|
          line = line.strip
          next if line.empty? || line.start_with?("#")

          begin
            data = Oj.load(line, mode: :compat, symbol_keys: true)
            entities << data if valid_entity?(data)
          rescue Oj::ParseError => e
            debug_me "Warning: Could not parse line #{index + 1}: #{e.message}"
          end
        end

        entities
      end

      # Write entities to file
      def write_entities(entities)
        FileUtils.mkdir_p(File.dirname(path))

        File.open(path, "w") do |f|
          f.puts "# TrakFlow task tracker data"
          f.puts "# Generated at #{Time.now.utc.iso8601}"
          f.puts ""

          entities.each do |entity|
            f.puts Oj.dump(entity, mode: :compat)
          end
        end
      end

      # Incremental export - only export changed entities
      def incremental_export(db, changed_ids)
        return export(db) unless File.exist?(path)

        existing = read_entities
        existing_by_id = {}

        existing.each do |entity|
          id = entity.dig(:data, :id)
          existing_by_id["#{entity[:type]}-#{id}"] = entity if id
        end

        changed_ids.each do |task_id|
          task = db.find_task(task_id)
          if task
            key = "task-#{task_id}"
            existing_by_id[key] = { type: "task", data: task.to_h }

            db.find_dependencies(task_id, direction: :outgoing).each do |dep|
              dep_key = "dependency-#{dep.id}"
              existing_by_id[dep_key] = { type: "dependency", data: dep.to_h }
            end

            db.find_labels(task_id).each do |label|
              label_key = "label-#{label.id}"
              existing_by_id[label_key] = { type: "label", data: label.to_h }
            end

            db.find_comments(task_id).each do |comment|
              comment_key = "comment-#{comment.id}"
              existing_by_id[comment_key] = { type: "comment", data: comment.to_h }
            end
          else
            existing_by_id.delete("task-#{task_id}")
          end
        end

        write_entities(existing_by_id.values)
        db.mark_clean!
      end

      private

      def valid_entity?(data)
        return false unless data.is_a?(Hash)
        return false unless ENTITY_TYPES.include?(data[:type])
        return false unless data[:data].is_a?(Hash)

        true
      end

      def handle_orphans(tasks, handling)
        task_ids = Set.new(tasks.map(&:id))
        orphans = []
        valid = []

        tasks.each do |task|
          if task.parent_id && !task_ids.include?(task.parent_id)
            orphans << task
          else
            valid << task
          end
        end

        return valid if orphans.empty?

        case handling
        when "allow"
          valid + orphans
        when "skip"
          debug_me "Skipping #{orphans.size} orphaned tasks"
          valid
        when "resurrect"
          orphans.each do |orphan|
            debug_me "Resurrecting orphan: #{orphan.id} (parent: #{orphan.parent_id})"
            orphan.parent_id = nil
          end
          valid + orphans
        when "strict"
          raise ValidationError, "Found #{orphans.size} orphaned tasks with missing parents"
        else
          valid + orphans
        end
      end
    end
  end
end
