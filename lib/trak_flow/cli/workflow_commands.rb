# frozen_string_literal: true

module TrakFlow
  class CLI < Thor
    # Workflow subcommands (running instances of Plans)
    class WorkflowCommands < Thor
      class_option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"

      desc "list", "List Workflows"
      option :ephemeral, aliases: "-e", type: :boolean, default: false, desc: "Show only ephemeral Workflows"
      option :plan, type: :string, desc: "Filter by source Plan ID"
      def list
        with_database do |db|
          workflows = db.find_workflows(plan_id: options[:plan])
          workflows = workflows.select(&:ephemeral?) if options[:ephemeral]

          output(workflows.map(&:to_h)) do
            if workflows.empty?
              puts "No workflows found"
            else
              puts "Workflows:"
              workflows.each do |wf|
                ephemeral_tag = wf.ephemeral? ? " [ephemeral]" : ""
                source_tag = wf.source_plan_id ? " (from: #{wf.source_plan_id})" : ""
                puts "  #{wf.id}: #{wf.title} (#{wf.status})#{ephemeral_tag}#{source_tag}"
              end
            end
          end
        end
      end

      desc "show ID", "Show Workflow with its Tasks"
      def show(id)
        with_database do |db|
          workflow = db.find_task!(id)
          tasks = db.find_workflow_tasks(id)

          output({ workflow: workflow.to_h, tasks: tasks.map(&:to_h) }) do
            puts "Workflow: #{workflow.id} - #{workflow.title}"
            puts "Status: #{workflow.status}"
            puts "Ephemeral: #{workflow.ephemeral?}"
            puts "Source Plan: #{workflow.source_plan_id || "(none)"}"
            puts ""
            puts "Tasks (#{tasks.size}):"
            if tasks.empty?
              puts "  (no tasks)"
            else
              tasks.each { |task| puts "  #{status_icon(task.status)} #{task.id}: #{task.title}" }
            end
          end
        end
      end

      desc "discard ID", "Discard an ephemeral Workflow"
      def discard(id)
        with_database do |db|
          workflow = db.find_task!(id)
          raise Error, "Can only discard ephemeral Workflows" unless workflow.discardable?

          db.child_tasks(id).each { |child| db.delete_task(child.id) }
          db.delete_task(id)

          output({ discarded: id }) do
            puts "Discarded Workflow: #{id}"
          end
        end
      end

      desc "summarize ID", "Summarize and close a Workflow"
      option :summary, aliases: "-s", type: :string, required: true, desc: "Summary text or file path"
      def summarize(id)
        with_database do |db|
          workflow = db.find_task!(id)

          summary_text = File.exist?(options[:summary]) ? File.read(options[:summary]) : options[:summary]

          workflow.notes = "#{workflow.notes}\n\n[Summary]\n#{summary_text}".strip
          workflow.close!(reason: "summarized")
          db.update_task(workflow)

          db.child_tasks(id).each do |child|
            child.close!(reason: "workflow summarized")
            db.update_task(child)
          end

          output(workflow.to_h) do
            puts "Summarized Workflow: #{id}"
          end
        end
      end

      desc "gc", "Garbage collect old ephemeral Workflows"
      option :age, type: :string, default: "24h", desc: "Maximum age (e.g., 24h, 7d)"
      def gc
        with_database do |db|
          hours = parse_duration(options[:age])
          count = db.garbage_collect_ephemeral(max_age_hours: hours)

          output({ collected: count }) do
            puts "Collected #{count} ephemeral Workflow(s)"
          end
        end
      end

      private

      def parse_duration(str)
        match = str.match(/^(\d+)(h|d|w)$/)
        return 24 unless match

        num = match[1].to_i
        case match[2]
        when "h" then num
        when "d" then num * 24
        when "w" then num * 24 * 7
        else 24
        end
      end

      # Delegate helper methods to parent CLI
      def with_database(&block) = CLI.new.with_database(&block)
      def status_icon(status) = CLI.new.status_icon(status)

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
