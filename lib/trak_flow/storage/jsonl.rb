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
        # Export regular tasks (excluding ephemeral) and include Plans
        entities = db.list_tasks(include_ephemeral: false, include_plans: true, include_tombstones: true)
                     .map { |task| { type: "task", data: task.to_h } }

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

        models = build_import_models(read_entities)
        tasks = handle_orphans(models[:task], orphan_handling)

        db.import_tasks(tasks)

        import_errors = import_entities(db, :add_dependency, models[:dependency], error_policy)
        import_errors += import_entities(db, :add_label, models[:label], error_policy)
        import_errors += import_entities(db, :add_comment, models[:comment], error_policy)

        raise_if_strict_errors(import_errors, error_policy)
      end

      private

      IMPORT_MODEL_CLASSES = {
        "task" => Models::Task,
        "dependency" => Models::Dependency,
        "label" => Models::Label,
        "comment" => Models::Comment
      }.freeze

      private_constant :IMPORT_MODEL_CLASSES

      # Groups raw JSONL entities into model instances keyed by type;
      # entities with an unknown type are dropped.
      def build_import_models(entities)
        models = { task: [], dependency: [], label: [], comment: [] }

        entities.each do |entity|
          klass = IMPORT_MODEL_CLASSES[entity[:type]]
          models[entity[:type].to_sym] << klass.from_hash(entity[:data]) if klass
        end

        models
      end

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

        entities_by_key = index_entities(read_entities)
        changed_ids.each { |task_id| apply_task_change(db, task_id, entities_by_key) }

        write_entities(entities_by_key.values)
        db.mark_clean!
      end

      private

      # Indexes entities by "type-id" for incremental merging.
      def index_entities(entities)
        entities.each_with_object({}) do |entity, index|
          id = entity.dig(:data, :id)
          index["#{entity[:type]}-#{id}"] = entity if id
        end
      end

      # Replaces one task's entities in the index — or removes the task's
      # entry when it no longer exists in the database.
      def apply_task_change(db, task_id, index)
        task = db.find_task(task_id)
        return index.delete("task-#{task_id}") unless task

        index["task-#{task_id}"] = { type: "task", data: task.to_h }

        db.find_dependencies(task_id, direction: :outgoing).each do |dep|
          index["dependency-#{dep.id}"] = { type: "dependency", data: dep.to_h }
        end

        db.find_labels(task_id).each do |label|
          index["label-#{label.id}"] = { type: "label", data: label.to_h }
        end

        db.find_comments(task_id).each do |comment|
          index["comment-#{comment.id}"] = { type: "comment", data: comment.to_h }
        end
      end

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
          # "allow" and any unrecognized handling keep orphans as-is
          valid + orphans
        end
      end
    end
  end
end
