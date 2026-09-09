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
          candidates = cleanup_candidates(db)
          count = candidates.size

          if candidates.empty?
            puts "No tasks to clean up"
            return
          end

          return print_cleanup_dry_run(candidates) if options[:dry_run]
          return unless options[:force] || confirm_cleanup?(count)

          delete_candidates(db, candidates)

          output({ deleted: count }) do
            puts "Deleted #{count} task(s)"
          end
        end
      end

      desc "compact", "Compact the database"
      option :analyze, type: :boolean, default: false, desc: "Show compaction stats"
      option :apply, type: :boolean, default: false, desc: "Apply compaction"
      def compact
        with_database do |db|
          if options[:analyze]
            stats = compaction_stats(db)
            output(stats) do
              stats.each { |k, v| puts "#{k}: #{v}" }
            end
          elsif options[:apply]
            tombstone_old_closed_tasks(db)
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

          if (output_path = options[:output])
            File.write(output_path, graph_output)
            puts "Graph written to #{output_path}"
          else
            puts graph_output
          end
        end
      end

      desc "analyze", "Analyze the task graph"
      def analyze
        with_database do |db|
          analysis = Graph::DependencyGraph.new(db).analyze
          output(analysis) { print_analysis(analysis) }
        end
      end

      private

      def print_analysis(analysis)
        analysis.each do |k, v|
          if v.is_a?(Array)
            puts "#{k}:"
            v.each { |item| puts "  - #{item}" }
          else
            puts "#{k}: #{v}"
          end
        end
      end

      # Closed tasks (tombstones included) whose closed_at is older than --older-than days.
      def cleanup_candidates(db)
        cutoff = Time.now.utc - (options[:older_than] * 24 * 60 * 60)
        db.list_tasks(status: "closed", include_tombstones: true)
          .select { |i| i.closed_at && i.closed_at < cutoff }
      end

      def print_cleanup_dry_run(candidates)
        puts "Would delete #{candidates.size} task(s):"
        candidates.each { |i| puts "  #{i.id}: #{i.title}" }
      end

      def confirm_cleanup?(count)
        puts "About to delete #{count} task(s). Continue? (y/n)"
        $stdin.gets.strip.downcase == "y"
      end

      def delete_candidates(db, candidates)
        candidates.each do |task|
          db.child_tasks(task.id).each { |c| db.delete_task(c.id) } if options[:cascade]
          db.delete_task(task.id)
        end
      end

      def compaction_stats(db)
        {
          total_tasks: db.all_task_ids.size,
          closed_tasks: db.list_tasks(status: "closed", include_tombstones: true).size,
          ephemeral: db.find_ephemeral_workflows.size,
          plans: db.find_plans.size,
          workflows: db.find_workflows.size
        }
      end

      # Marks closed tasks older than 30 days as tombstones.
      def tombstone_old_closed_tasks(db)
        cutoff = Time.now.utc - (30 * 24 * 60 * 60)
        db.list_tasks(status: "closed").each do |task|
          next unless task.closed_at && task.closed_at < cutoff

          task.status = "tombstone"
          db.update_task(task)
        end
      end

      # Delegate helper methods to parent CLI
      def with_database(&) = CLI.new.with_database(&)

      def output(json_data)
        if options[:json]
          puts Oj.dump(json_data, mode: :compat, indent: 2)
        else
          yield
        end
      end
    end
  end
end
