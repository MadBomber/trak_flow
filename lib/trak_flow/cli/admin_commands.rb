# frozen_string_literal: true

module TrakFlow
  class CLI < Thor
    # Admin subcommands
    class AdminCommands < Thor
      class_option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"

      desc "cleanup", "Clean up old closed tasks"
      option :older_than, type: :numeric, default: 30, desc: "Days since closed"
      option :dry_run, type: :boolean, default: false, desc: "Show what would be deleted"
      option :force, type: :boolean, default: false, desc: "Skip confirmation"
      option :cascade, type: :boolean, default: false, desc: "Also delete children"
      def cleanup
        with_database do |db|
          cutoff = Time.now.utc - (options[:older_than] * 24 * 60 * 60)
          candidates = db.list_tasks(status: "closed", include_tombstones: true)
                         .select { |i| i.closed_at && i.closed_at < cutoff }

          if candidates.empty?
            puts "No tasks to clean up"
            return
          end

          if options[:dry_run]
            puts "Would delete #{candidates.size} task(s):"
            candidates.each { |i| puts "  #{i.id}: #{i.title}" }
            return
          end

          unless options[:force]
            puts "About to delete #{candidates.size} task(s). Continue? (y/n)"
            return unless $stdin.gets.strip.downcase == "y"
          end

          candidates.each do |task|
            db.child_tasks(task.id).each { |c| db.delete_task(c.id) } if options[:cascade]
            db.delete_task(task.id)
          end

          output({ deleted: candidates.size }) do
            puts "Deleted #{candidates.size} task(s)"
          end
        end
      end

      desc "compact", "Compact the database"
      option :analyze, type: :boolean, default: false, desc: "Show compaction stats"
      option :apply, type: :boolean, default: false, desc: "Apply compaction"
      def compact
        with_database do |db|
          stats = {
            total_tasks: db.all_task_ids.size,
            closed_tasks: db.list_tasks(status: "closed", include_tombstones: true).size,
            ephemeral: db.find_ephemeral_workflows.size,
            plans: db.find_plans.size,
            workflows: db.find_workflows.size
          }

          if options[:analyze]
            output(stats) do
              stats.each { |k, v| puts "#{k}: #{v}" }
            end
            return
          end

          if options[:apply]
            db.list_tasks(status: "closed").each do |task|
              next unless task.closed_at && task.closed_at < (Time.now.utc - 30 * 24 * 60 * 60)

              task.status = "tombstone"
              db.update_task(task)
            end
            puts "Compaction complete"
          else
            puts "Use --analyze to see stats or --apply to compact"
          end
        end
      end

      desc "graph", "Generate dependency graph"
      option :format, type: :string, default: "dot", desc: "Output format (dot, svg)"
      option :output, aliases: "-o", type: :string, desc: "Output file"
      option :include_closed, type: :boolean, default: false, desc: "Include closed tasks"
      def graph
        with_database do |db|
          dep_graph = Graph::DependencyGraph.new(db)

          graph_output = case options[:format]
            when "svg" then dep_graph.to_svg(include_closed: options[:include_closed])
            else dep_graph.to_dot(include_closed: options[:include_closed])
            end

          if options[:output]
            File.write(options[:output], graph_output)
            puts "Graph written to #{options[:output]}"
          else
            puts graph_output
          end
        end
      end

      desc "analyze", "Analyze the task graph"
      def analyze
        with_database do |db|
          dep_graph = Graph::DependencyGraph.new(db)
          analysis = dep_graph.analyze

          output(analysis) do
            analysis.each do |k, v|
              if v.is_a?(Array)
                puts "#{k}:"
                v.each { |item| puts "  - #{item}" }
              else
                puts "#{k}: #{v}"
              end
            end
          end
        end
      end

      private

      # Delegate helper methods to parent CLI
      def with_database(&block) = CLI.new.with_database(&block)

      def output(json_data, &human_block)
        if options[:json]
          puts Oj.dump(json_data, mode: :compat, indent: 2)
        else
          human_block.call
        end
      end
    end
  end
end
