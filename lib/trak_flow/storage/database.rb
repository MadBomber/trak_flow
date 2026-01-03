# frozen_string_literal: true

module TrakFlow
  module Storage
    # SQLite database layer for fast local queries
    # This is the gitignored working copy that provides millisecond response times
    class Database
      attr_reader :db

      def initialize(db_path = nil)
        @db_path = db_path || TrakFlow.database_path
        @db = nil
        @dirty = false
      end

      def connect
        @db = Sequel.sqlite(@db_path)
        setup_schema
        self
      end

      def close
        @db&.disconnect
        @db = nil
      end

      def connected?
        !@db.nil?
      end

      def dirty?
        @dirty
      end

      def mark_dirty!
        @dirty = true
      end

      def mark_clean!
        @dirty = false
      end

      # Task operations

      def create_task(task)
        task.validate!
        existing_ids = @db[:tasks].select_map(:id)
        task.id ||= IdGenerator.generate(existing_ids: existing_ids)
        task.update_content_hash!

        @db[:tasks].insert(task_to_row(task))
        mark_dirty!
        task
      end

      def find_task(id)
        row = @db[:tasks].where(id: id).first
        return nil unless row

        Models::Task.from_hash(row)
      end

      def find_task!(id)
        task = find_task(id)
        raise TaskNotFoundError, "Task not found: #{id}" unless task

        task
      end

      def update_task(task)
        task.validate!
        task.touch!

        @db[:tasks].where(id: task.id).update(task_to_row(task))
        mark_dirty!
        task
      end

      def delete_task(id)
        @db[:tasks].where(id: id).delete
        @db[:labels].where(task_id: id).delete
        @db[:dependencies].where(source_id: id).or(target_id: id).delete
        @db[:comments].where(task_id: id).delete
        mark_dirty!
      end

      def list_tasks(filters = {})
        dataset = @db[:tasks]

        dataset = apply_status_filter(dataset, filters[:status])
        dataset = apply_priority_filter(dataset, filters)
        dataset = apply_type_filter(dataset, filters[:type])
        dataset = apply_assignee_filter(dataset, filters[:assignee])
        dataset = apply_text_filters(dataset, filters)
        dataset = apply_date_filters(dataset, filters)
        dataset = apply_null_filters(dataset, filters)
        dataset = dataset.where(ephemeral: false) unless filters[:include_ephemeral]
        dataset = dataset.where(plan: false) unless filters[:include_plans]
        dataset = dataset.exclude(status: "tombstone") unless filters[:include_tombstones]

        dataset.order(Sequel.asc(:priority), Sequel.desc(:updated_at)).map do |row|
          Models::Task.from_hash(row)
        end
      end

      def all_task_ids
        @db[:tasks].select_map(:id)
      end

      # Dependency operations

      def add_dependency(dependency)
        dependency.validate!
        detect_cycle!(dependency)

        # Check if dependency already exists (idempotent operation)
        existing = @db[:dependencies].where(
          source_id: dependency.source_id,
          target_id: dependency.target_id,
          type: dependency.type
        ).first

        return dependency if existing

        @db[:dependencies].insert(dependency_to_row(dependency))
        rebuild_blocked_cache!
        mark_dirty!
        dependency
      end

      def remove_dependency(source_id, target_id, type: nil)
        dataset = @db[:dependencies].where(source_id: source_id, target_id: target_id)
        dataset = dataset.where(type: type) if type

        deleted = dataset.delete
        rebuild_blocked_cache! if deleted.positive?
        mark_dirty! if deleted.positive?
        deleted
      end

      def find_dependencies(issue_id, direction: :both)
        deps = []

        if direction == :both || direction == :outgoing
          @db[:dependencies].where(source_id: issue_id).each do |row|
            deps << Models::Dependency.from_hash(row)
          end
        end

        if direction == :both || direction == :incoming
          @db[:dependencies].where(target_id: issue_id).each do |row|
            deps << Models::Dependency.from_hash(row)
          end
        end

        deps
      end

      def blocking_dependencies(issue_id)
        @db[:dependencies]
          .where(target_id: issue_id)
          .where(type: Models::Dependency::BLOCKING_TYPES)
          .map { |row| Models::Dependency.from_hash(row) }
      end

      # Label operations

      def add_label(label)
        label.validate!

        existing = @db[:labels].where(task_id: label.task_id, name: label.name).first
        return Models::Label.from_hash(existing) if existing

        @db[:labels].insert(label_to_row(label))
        mark_dirty!
        label
      end

      def remove_label(task_id, name)
        deleted = @db[:labels].where(task_id: task_id, name: name).delete
        mark_dirty! if deleted.positive?
        deleted
      end

      def find_labels(task_id)
        @db[:labels].where(task_id: task_id).map do |row|
          Models::Label.from_hash(row)
        end
      end

      def all_labels
        @db[:labels].distinct.select_map(:name).sort
      end

      def set_state(task_id, dimension, value, reason: nil)
        prefix = "#{dimension}:"
        @db[:labels].where(task_id: task_id).where(Sequel.like(:name, "#{prefix}%")).delete

        label = Models::Label.new(task_id: task_id, name: "#{dimension}:#{value}")
        add_label(label)

        if reason
          task = find_task!(task_id)
          task.notes = "#{task.notes}\n[State] #{dimension}=#{value}: #{reason}".strip
          update_task(task)
        end

        label
      end

      def get_state(task_id, dimension)
        label = @db[:labels].where(task_id: task_id).where(Sequel.like(:name, "#{dimension}:%")).first
        return nil unless label

        label[:name].split(":", 2).last
      end

      # Comment operations

      def add_comment(comment)
        comment.validate!
        @db[:comments].insert(comment_to_row(comment))
        mark_dirty!
        comment
      end

      def find_comments(task_id)
        @db[:comments].where(task_id: task_id).order(:created_at).map do |row|
          Models::Comment.from_hash(row)
        end
      end

      # Ready work detection

      def ready_tasks
        blocked_ids = @db[:blocked_tasks].select_map(:task_id)

        @db[:tasks]
          .where(status: "open")
          .where(ephemeral: false)
          .where(plan: false)
          .exclude(id: blocked_ids)
          .order(Sequel.asc(:priority), Sequel.desc(:updated_at))
          .map { |row| Models::Task.from_hash(row) }
      end

      def blocked_tasks
        blocked_ids = @db[:blocked_tasks].select_map(:task_id)

        @db[:tasks]
          .where(id: blocked_ids)
          .where(ephemeral: false)
          .where(plan: false)
          .map { |row| Models::Task.from_hash(row) }
      end

      # Stale tasks

      def stale_tasks(days: 30, status: nil)
        cutoff = Time.now.utc - (days * 24 * 60 * 60)
        dataset = @db[:tasks].where(ephemeral: false).where(plan: false).where { updated_at < cutoff }
        dataset = dataset.where(status: status) if status
        dataset.order(:updated_at).map { |row| Models::Task.from_hash(row) }
      end

      # Child tasks (for epics)

      def child_tasks(parent_id)
        @db[:tasks].where(parent_id: parent_id).map do |row|
          Models::Task.from_hash(row)
        end
      end

      def create_child_task(parent_id, attrs)
        parent = find_task!(parent_id)
        child_count = @db[:tasks].where(parent_id: parent_id).count
        child_id = IdGenerator.generate_child_id(parent_id, child_count + 1)

        task = Models::Task.new(attrs.merge(id: child_id, parent_id: parent_id))
        create_task(task)

        dep = Models::Dependency.new(
          source_id: parent_id,
          target_id: child_id,
          type: "parent-child"
        )
        add_dependency(dep)

        task
      end

      # Plan operations

      def find_plans
        @db[:tasks].where(plan: true).order(:title).map do |row|
          Models::Task.from_hash(row)
        end
      end

      def find_plan_tasks(plan_id)
        @db[:tasks].where(parent_id: plan_id).order(Sequel.asc(:priority), :title).map do |row|
          Models::Task.from_hash(row)
        end
      end

      def mark_as_plan(task_id)
        task = find_task!(task_id)
        task.plan = true
        task.status = "open"
        task.ephemeral = false
        update_task(task)
      end

      # Workflow operations

      def find_workflows(plan_id: nil)
        dataset = @db[:tasks].where(plan: false)
        dataset = dataset.exclude(source_plan_id: nil).exclude(source_plan_id: "")
        dataset = dataset.where(source_plan_id: plan_id) if plan_id
        dataset.order(Sequel.desc(:created_at)).map do |row|
          Models::Task.from_hash(row)
        end
      end

      def find_workflow_tasks(workflow_id)
        @db[:tasks].where(parent_id: workflow_id).order(Sequel.asc(:priority), :title).map do |row|
          Models::Task.from_hash(row)
        end
      end

      # Ephemeral task operations

      def find_ephemeral_workflows
        @db[:tasks].where(ephemeral: true).map do |row|
          Models::Task.from_hash(row)
        end
      end

      def garbage_collect_ephemeral(max_age_hours: 24)
        cutoff = Time.now.utc - (max_age_hours * 60 * 60)
        old_ephemeral = @db[:tasks].where(ephemeral: true).where { created_at < cutoff }.select_map(:id)

        old_ephemeral.each { |id| delete_task(id) }
        old_ephemeral.size
      end

      # Bulk operations

      def import_tasks(tasks)
        @db.transaction do
          tasks.each do |task|
            existing = find_task(task.id)
            if existing
              update_task(task) if task.content_hash != existing.content_hash
            else
              @db[:tasks].insert(task_to_row(task))
            end
          end
        end
        rebuild_blocked_cache!
        mark_dirty!
      end

      def clear!
        @db[:tasks].delete
        @db[:dependencies].delete
        @db[:labels].delete
        @db[:comments].delete
        @db[:blocked_tasks].delete
        mark_dirty!
      end

      private

      def setup_schema
        @db.create_table?(:tasks) do
          String :id, primary_key: true
          String :title, null: false
          Text :description
          String :status, default: "open"
          Integer :priority, default: 2
          String :type, default: "task"
          String :assignee
          String :parent_id
          DateTime :created_at
          DateTime :updated_at
          DateTime :closed_at
          String :content_hash
          TrueClass :plan, default: false
          String :source_plan_id
          TrueClass :ephemeral, default: false
          Text :notes

          index :status
          index :priority
          index :type
          index :assignee
          index :parent_id
          index :plan
          index :source_plan_id
          index :ephemeral
        end

        migrate_schema_if_needed!

        @db.create_table?(:dependencies) do
          String :id, primary_key: true
          String :source_id, null: false
          String :target_id, null: false
          String :type, default: "blocks"
          DateTime :created_at

          index :source_id
          index :target_id
          index :type
        end

        @db.create_table?(:labels) do
          String :id, primary_key: true
          String :task_id, null: false
          String :name, null: false
          DateTime :created_at

          index :task_id
          index :name
          unique %i[task_id name]
        end

        @db.create_table?(:comments) do
          String :id, primary_key: true
          String :task_id, null: false
          String :author
          Text :body, null: false
          DateTime :created_at
          DateTime :updated_at

          index :task_id
        end

        @db.create_table?(:blocked_tasks) do
          String :task_id, primary_key: true

          index :task_id
        end
      end

      def task_to_row(task)
        {
          id: task.id,
          title: task.title,
          description: task.description,
          status: task.status,
          priority: task.priority,
          type: task.type,
          assignee: task.assignee,
          parent_id: task.parent_id,
          created_at: task.created_at,
          updated_at: task.updated_at,
          closed_at: task.closed_at,
          content_hash: task.content_hash,
          plan: task.plan,
          source_plan_id: task.source_plan_id,
          ephemeral: task.ephemeral,
          notes: task.notes
        }
      end

      def dependency_to_row(dep)
        {
          id: dep.id,
          source_id: dep.source_id,
          target_id: dep.target_id,
          type: dep.type,
          created_at: dep.created_at
        }
      end

      def label_to_row(label)
        {
          id: label.id,
          task_id: label.task_id,
          name: label.name,
          created_at: label.created_at
        }
      end

      def comment_to_row(comment)
        {
          id: comment.id,
          task_id: comment.task_id,
          author: comment.author,
          body: comment.body,
          created_at: comment.created_at,
          updated_at: comment.updated_at
        }
      end

      def apply_status_filter(dataset, status)
        return dataset unless status

        if status.is_a?(Array)
          dataset.where(status: status)
        else
          dataset.where(status: status)
        end
      end

      def apply_priority_filter(dataset, filters)
        dataset = dataset.where(priority: filters[:priority]) if filters[:priority]
        dataset = dataset.where { priority >= filters[:priority_min] } if filters[:priority_min]
        dataset = dataset.where { priority <= filters[:priority_max] } if filters[:priority_max]
        dataset
      end

      def apply_type_filter(dataset, type)
        return dataset unless type

        dataset.where(type: type)
      end

      def apply_assignee_filter(dataset, assignee)
        return dataset unless assignee

        dataset.where(assignee: assignee)
      end

      def apply_text_filters(dataset, filters)
        if filters[:title_contains]
          pattern = "%#{escape_like_pattern(filters[:title_contains])}%"
          dataset = dataset.where(Sequel.ilike(:title, pattern))
        end
        if filters[:desc_contains]
          pattern = "%#{escape_like_pattern(filters[:desc_contains])}%"
          dataset = dataset.where(Sequel.ilike(:description, pattern))
        end
        if filters[:notes_contains]
          pattern = "%#{escape_like_pattern(filters[:notes_contains])}%"
          dataset = dataset.where(Sequel.ilike(:notes, pattern))
        end
        dataset
      end

      def escape_like_pattern(str)
        str.gsub(/[%_\\]/) { |match| "\\#{match}" }
      end

      def apply_date_filters(dataset, filters)
        dataset = dataset.where { created_at >= filters[:created_after] } if filters[:created_after]
        dataset = dataset.where { created_at <= filters[:created_before] } if filters[:created_before]
        dataset = dataset.where { updated_at >= filters[:updated_after] } if filters[:updated_after]
        dataset = dataset.where { updated_at <= filters[:updated_before] } if filters[:updated_before]
        dataset = dataset.where { closed_at >= filters[:closed_after] } if filters[:closed_after]
        dataset = dataset.where { closed_at <= filters[:closed_before] } if filters[:closed_before]
        dataset
      end

      def apply_null_filters(dataset, filters)
        dataset = dataset.where(description: [nil, ""]) if filters[:empty_description]
        dataset = dataset.where(assignee: nil) if filters[:no_assignee]
        dataset
      end

      def detect_cycle!(new_dep)
        return unless new_dep.blocking?

        visited = Set.new
        queue = [new_dep.target_id]

        while queue.any?
          current = queue.shift
          return if visited.include?(current)

          visited << current

          raise DependencyCycleError, "Adding this dependency would create a cycle" if current == new_dep.source_id

          @db[:dependencies]
            .where(source_id: current)
            .where(type: Models::Dependency::BLOCKING_TYPES)
            .each { |row| queue << row[:target_id] }
        end
      end

      def rebuild_blocked_cache!
        @db[:blocked_tasks].delete

        blocked = Set.new
        open_tasks = @db[:tasks].where(status: "open").select_map(:id)

        open_tasks.each do |task_id|
          blocked << task_id if task_blocked?(task_id)
        end

        blocked.each do |id|
          @db[:blocked_tasks].insert(task_id: id)
        end
      end

      def task_blocked?(task_id, visited = Set.new)
        return false if visited.include?(task_id)

        visited << task_id
        blocking_deps = @db[:dependencies]
          .where(target_id: task_id)
          .where(type: Models::Dependency::BLOCKING_TYPES)

        blocking_deps.any? { |dep| blocker_active?(dep, visited) }
      end

      def blocker_active?(dep, visited)
        blocker = @db[:tasks].where(id: dep[:source_id]).first
        return false unless blocker

        blocker_open = !%w[closed tombstone].include?(blocker[:status])
        return true if blocker_open

        dep[:type] == "parent-child" && task_blocked?(dep[:source_id], visited)
      end

      def migrate_schema_if_needed!
        columns = @db[:tasks].columns

        unless columns.include?(:plan)
          @db.alter_table(:tasks) { add_column :plan, TrueClass, default: false } rescue nil
          @db.add_index :tasks, :plan rescue nil
        end
        unless columns.include?(:source_plan_id)
          @db.alter_table(:tasks) { add_column :source_plan_id, String } rescue nil
          @db.add_index :tasks, :source_plan_id rescue nil
        end
        unless columns.include?(:ephemeral)
          @db.alter_table(:tasks) { add_column :ephemeral, TrueClass, default: false } rescue nil
          @db.add_index :tasks, :ephemeral rescue nil
        end
      end
    end
  end
end
