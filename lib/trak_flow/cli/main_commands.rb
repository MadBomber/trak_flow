# frozen_string_literal: true

module TrakFlow
  class CLI < Thor
    desc "version", "Show version"

    def version
      puts "trak_flow #{VERSION}"
    end

    desc "init", "Initialize TrakFlow in the current directory"
    option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"
    option :stealth, type: :boolean, default: false, desc: "Local-only mode without git integration"

    def init
      if TrakFlow.initialized?
        output({ success: false, error: "TrakFlow already initialized" }) do
          puts pastel.red("Error: TrakFlow already initialized in #{TrakFlow.trak_flow_dir}")
        end
        return
      end

      FileUtils.mkdir_p(TrakFlow.trak_flow_dir)

      db = Storage::Database.new
      db.connect

      TrakFlow.config.set("stealth", options[:stealth])

      jsonl = Storage::Jsonl.new
      jsonl.write_entities([])

      setup_gitignore unless options[:stealth]

      output({ success: true, path: TrakFlow.trak_flow_dir }) do
        puts pastel.green("Initialized TrakFlow in #{TrakFlow.trak_flow_dir}")
      end
    end

    desc "info", "Show database and configuration info"
    option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"

    def info
      TrakFlow.ensure_initialized!

      info_data = {
        database_path: TrakFlow.database_path,
        jsonl_path: TrakFlow.jsonl_path,
        config_path: TrakFlow.config_path,
        initialized: TrakFlow.initialized?,
      }

      output(info_data) do
        info_data.each { |k, v| puts "#{k}: #{v}" }
      end
    end

    desc "create TITLE", "Create a new task"
    option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"
    option :type, aliases: "-t", type: :string, default: "task", desc: "Task type (bug, feature, task, epic, chore)"
    option :priority, aliases: "-p", type: :numeric, default: 2, desc: "Priority (0=critical, 4=backlog)"
    option :description, aliases: "-d", type: :string, desc: "Task description"
    option :assignee, aliases: "-a", type: :string, desc: "Assignee"
    option :labels, aliases: "-l", type: :array, desc: "Labels to add"
    option :parent, type: :string, desc: "Parent task ID (creates child task)"
    option :deps, type: :array, desc: "Dependencies (format: type:id)"
    option :body_file, type: :string, desc: "Read description from file (use - for stdin)"
    option :plan, type: :boolean, default: false, desc: "Create as a Plan (workflow blueprint)"
    option :ephemeral, type: :boolean, default: false, desc: "Create as ephemeral (one-shot, garbage collectible)"

    def create(title)
      validate_option!(:type, TrakFlow::TYPES, options[:type])
      validate_option!(:priority, TrakFlow::PRIORITIES, options[:priority])

      with_database do |db|
        description = options[:description]

        if options[:body_file]
          description = options[:body_file] == "-" ? $stdin.read : File.read(options[:body_file])
        end

        raise ValidationError, "Plans cannot be ephemeral" if options[:plan] && options[:ephemeral]

        task = if options[:parent]
            db.create_child_task(options[:parent], {
              title: title,
              description: description,
              type: options[:type],
              priority: options[:priority],
              assignee: options[:assignee],
              ephemeral: options[:ephemeral],
            })
          else
            new_task = Models::Task.new(
              title: title,
              description: description,
              type: options[:type],
              priority: options[:priority],
              assignee: options[:assignee],
              plan: options[:plan],
              ephemeral: options[:ephemeral],
            )
            db.create_task(new_task)
          end

        options[:labels]&.each do |label_name|
          db.add_label(Models::Label.new(task_id: task.id, name: label_name))
        end

        options[:deps]&.each do |dep_spec|
          type, target_id = dep_spec.split(":", 2)
          db.add_dependency(Models::Dependency.new(source_id: task.id, target_id: target_id, type: type))
        end

        output(task.to_h) do
          puts "Created: #{pastel.bold(task.id)} - #{task.title}"
        end
      end
    end

    desc "show ID", "Show task details"
    option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"

    def show(id)
      with_database do |db|
        task = db.find_task!(id)
        labels = db.find_labels(id)
        deps = db.find_dependencies(id)
        comments = db.find_comments(id)

        output({ task: task.to_h, labels: labels.map(&:name), dependencies: deps.map(&:to_h), comments: comments.map(&:to_h) }) do
          print_task_details(task, labels, deps, comments)
        end
      end
    end

    desc "list", "List tasks"
    option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"
    option :status, aliases: "-s", type: :string, desc: "Filter by status"
    option :priority, aliases: "-p", type: :numeric, desc: "Filter by priority"
    option :type, aliases: "-t", type: :string, desc: "Filter by type"
    option :assignee, aliases: "-a", type: :string, desc: "Filter by assignee"
    option :label, type: :array, desc: "Filter by labels (AND)"
    option :label_any, type: :array, desc: "Filter by labels (OR)"
    option :title_contains, type: :string, desc: "Filter by title substring"
    option :limit, type: :numeric, desc: "Limit results"

    def list
      with_database do |db|
        filters = {
          status: options[:status],
          priority: options[:priority],
          type: options[:type],
          assignee: options[:assignee],
          title_contains: options[:title_contains],
        }.compact

        tasks = db.list_tasks(filters)

        if options[:label]
          tasks = tasks.select do |task|
            task_labels = db.find_labels(task.id).map(&:name)
            options[:label].all? { |l| task_labels.include?(l) }
          end
        end

        if options[:label_any]
          tasks = tasks.select do |task|
            task_labels = db.find_labels(task.id).map(&:name)
            options[:label_any].any? { |l| task_labels.include?(l) }
          end
        end

        tasks = tasks.take(options[:limit]) if options[:limit]

        output(tasks.map(&:to_h)) do
          if tasks.empty?
            puts "No tasks found"
          else
            print_tasks_table(tasks)
          end
        end
      end
    end

    desc "update ID", "Update a task"
    option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"
    option :status, aliases: "-s", type: :string, desc: "New status"
    option :priority, aliases: "-p", type: :numeric, desc: "New priority"
    option :title, type: :string, desc: "New title"
    option :description, aliases: "-d", type: :string, desc: "New description"
    option :assignee, aliases: "-a", type: :string, desc: "New assignee"

    def update(id)
      validate_option!(:status, TrakFlow::STATUSES, options[:status])
      validate_option!(:priority, TrakFlow::PRIORITIES, options[:priority])

      with_database do |db|
        task = db.find_task!(id)

        task.status = options[:status] if options[:status]
        task.priority = options[:priority] if options[:priority]
        task.title = options[:title] if options[:title]
        task.description = options[:description] if options[:description]
        task.assignee = options[:assignee] if options[:assignee]

        db.update_task(task)

        output(task.to_h) do
          puts "Updated: #{pastel.bold(task.id)} - #{task.title}"
        end
      end
    end

    desc "close ID", "Close a task"
    option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"
    option :reason, aliases: "-r", type: :string, desc: "Reason for closing"

    def close(id)
      with_database do |db|
        task = db.find_task!(id)
        task.close!(reason: options[:reason])
        db.update_task(task)

        output(task.to_h) do
          puts "Closed: #{pastel.bold(task.id)} - #{task.title}"
        end
      end
    end

    desc "reopen ID", "Reopen a closed task"
    option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"
    option :reason, aliases: "-r", type: :string, desc: "Reason for reopening"

    def reopen(id)
      with_database do |db|
        task = db.find_task!(id)
        task.reopen!(reason: options[:reason])
        db.update_task(task)

        output(task.to_h) do
          puts "Reopened: #{pastel.bold(task.id)} - #{task.title}"
        end
      end
    end

    desc "ready", "Show tasks ready for work (no blockers)"
    option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"

    def ready
      with_database do |db|
        tasks = db.ready_tasks

        output(tasks.map(&:to_h)) do
          if tasks.empty?
            puts "No ready tasks found"
          else
            puts pastel.bold("Ready for work:")
            print_tasks_table(tasks)
          end
        end
      end
    end

    desc "stale", "Show stale tasks"
    option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"
    option :days, type: :numeric, default: 30, desc: "Days since last update"
    option :status, type: :string, desc: "Filter by status"

    def stale
      with_database do |db|
        tasks = db.stale_tasks(days: options[:days], status: options[:status])

        output(tasks.map(&:to_h)) do
          if tasks.empty?
            puts "No stale tasks found"
          else
            puts pastel.bold("Stale tasks (#{options[:days]}+ days):")
            print_tasks_table(tasks)
          end
        end
      end
    end

    desc "sync", "Sync database with JSONL file"
    option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"

    def sync
      with_database do |db|
        jsonl = Storage::Jsonl.new

        if jsonl.exists?
          jsonl.import(db)
          output({ success: true, action: "imported", path: jsonl.path }) do
            puts pastel.green("Imported from #{jsonl.path}")
          end
        end

        jsonl.export(db)
        output({ success: true, action: "exported", path: jsonl.path }) do
          puts pastel.green("Exported to #{jsonl.path}")
        end

        unless TrakFlow.config.get("stealth") || TrakFlow.config.get("no_push")
          git_commit_and_push
        end
      end
    end

    # Subcommands
    desc "dep SUBCOMMAND", "Manage dependencies"
    subcommand "dep", DepCommands

    desc "label SUBCOMMAND", "Manage labels"
    subcommand "label", LabelCommands

    desc "plan SUBCOMMAND", "Plan operations (workflow blueprints)"
    subcommand "plan", PlanCommands

    desc "workflow SUBCOMMAND", "Workflow operations (running instances)"
    subcommand "workflow", WorkflowCommands

    desc "admin SUBCOMMAND", "Administrative commands"
    subcommand "admin", AdminCommands

    desc "config SUBCOMMAND", "Configuration management"
    subcommand "config", ConfigCommands

    private

    def print_task_details(task, labels, deps, comments)
      puts pastel.bold("Task: #{task.id}")
      puts "Title: #{task.title}"
      puts "Status: #{colorize_status(task.status)}"
      puts "Priority: #{colorize_priority(task.priority)}"
      puts "Type: #{task.type}"
      puts "Assignee: #{task.assignee || "unassigned"}"
      puts "Parent: #{task.parent_id}" if task.parent_id
      puts "Created: #{task.created_at}"
      puts "Updated: #{task.updated_at}"
      puts "Closed: #{task.closed_at}" if task.closed_at
      puts ""
      puts "Description:"
      puts task.description.empty? ? "(none)" : task.description
      puts ""
      puts "Labels: #{labels.empty? ? "(none)" : labels.map(&:name).join(", ")}"
      puts ""
      puts "Dependencies:"
      if deps.empty?
        puts "  (none)"
      else
        deps.each do |dep|
          direction = dep.source_id == task.id ? "->" : "<-"
          other_id = dep.source_id == task.id ? dep.target_id : dep.source_id
          puts "  #{direction} #{other_id} (#{dep.type})"
        end
      end
      puts ""
      puts "Comments: #{comments.size}"
      comments.each do |comment|
        puts "  [#{comment.created_at}] #{comment.author}: #{comment.body[0, 50]}..."
      end
    end

    def setup_gitignore
      gitignore_path = File.join(TrakFlow.trak_flow_dir, ".gitignore")
      File.write(gitignore_path, "trak_flow.db\n")
    end

    def validate_option!(name, valid_values, value)
      return if value.nil?
      return if valid_values.include?(value)

      valid_list = valid_values.join(", ")
      raise ValidationError, "Invalid #{name}: '#{value}'. Valid options: #{valid_list}"
    end

    def git_commit_and_push
      Dir.chdir(TrakFlow.root) do
        system("git add #{TrakFlow.jsonl_path} 2>/dev/null")
        system("git commit -m 'trak_flow: sync tasks' #{TrakFlow.jsonl_path} 2>/dev/null")
        system("git push 2>/dev/null") unless TrakFlow.config.get("no_push")
      end
    end
  end
end
