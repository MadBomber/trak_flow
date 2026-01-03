# frozen_string_literal: true

module TrakFlow
  class CLI < Thor
    # Plan subcommands (workflow blueprints)
    class PlanCommands < Thor
      class_option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"

      desc "create TITLE", "Create a new Plan (workflow blueprint)"
      option :description, aliases: "-d", type: :string, desc: "Plan description"
      option :type, aliases: "-t", type: :string, default: "task", desc: "Task type"
      option :priority, aliases: "-p", type: :numeric, default: 2, desc: "Priority"
      def create(title)
        with_database do |db|
          plan = Models::Task.new(
            title: title,
            description: options[:description] || "",
            type: options[:type],
            priority: options[:priority],
            plan: true
          )
          db.create_task(plan)

          output(plan.to_h) do
            puts "Created Plan: #{plan.id} - #{plan.title}"
          end
        end
      end

      desc "list", "List Plans"
      option :workflows, aliases: "-w", type: :boolean, default: false, desc: "Show Workflows instead of Plans"
      def list
        with_database do |db|
          if options[:workflows]
            items = db.find_workflows
            label = "Workflows"
          else
            items = db.find_plans
            label = "Plans"
          end

          output(items.map(&:to_h)) do
            if items.empty?
              puts "No #{label.downcase} found"
            else
              puts "#{label}:"
              items.each do |item|
                status_info = item.plan? ? "" : " (#{item.status})"
                ephemeral_tag = item.ephemeral? ? " [ephemeral]" : ""
                puts "  #{item.id}: #{item.title}#{status_info}#{ephemeral_tag}"
              end
            end
          end
        end
      end

      desc "show ID", "Show Plan with its Tasks"
      def show(id)
        with_database do |db|
          plan = db.find_task!(id)
          tasks = db.find_plan_tasks(id)

          output({ plan: plan.to_h, tasks: tasks.map(&:to_h) }) do
            puts "Plan: #{plan.id} - #{plan.title}"
            puts "Description: #{plan.description.empty? ? "(none)" : plan.description}"
            puts ""
            puts "Tasks (#{tasks.size}):"
            if tasks.empty?
              puts "  (no tasks defined)"
            else
              tasks.each { |task| puts "  #{task.id}: #{task.title} (P#{task.priority})" }
            end
          end
        end
      end

      desc "add PLAN_ID TITLE", "Add a Task to a Plan"
      option :description, aliases: "-d", type: :string, desc: "Task description"
      option :type, aliases: "-t", type: :string, default: "task", desc: "Task type"
      option :priority, aliases: "-p", type: :numeric, default: 2, desc: "Priority"
      def add(plan_id, title)
        with_database do |db|
          plan = db.find_task!(plan_id)
          raise Error, "#{plan_id} is not a Plan" unless plan.plan?

          task = db.create_child_task(plan_id, {
            title: title,
            description: options[:description] || "",
            type: options[:type],
            priority: options[:priority]
          })

          output(task.to_h) do
            puts "Added Task to Plan: #{task.id} - #{task.title}"
          end
        end
      end

      desc "start PLAN_ID", "Create a persistent Workflow from a Plan"
      option :var, type: :hash, default: {}, desc: "Template variables"
      def start(plan_id)
        instantiate_plan(plan_id, ephemeral: false)
      end

      desc "execute PLAN_ID", "Create an ephemeral Workflow from a Plan"
      option :var, type: :hash, default: {}, desc: "Template variables"
      def execute(plan_id)
        instantiate_plan(plan_id, ephemeral: true)
      end

      desc "convert ID", "Convert an existing Task to a Plan"
      def convert(id)
        with_database do |db|
          task = db.find_task!(id)
          raise Error, "Task is already a Plan" if task.plan?
          raise Error, "Cannot convert ephemeral tasks to Plans" if task.ephemeral?

          db.mark_as_plan(id)
          task = db.find_task!(id)

          output(task.to_h) do
            puts "Converted to Plan: #{task.id}"
          end
        end
      end

      private

      def instantiate_plan(plan_id, ephemeral:)
        with_database do |db|
          plan = db.find_task!(plan_id)
          raise Error, "#{plan_id} is not a Plan" unless plan.plan?

          vars = options[:var] || {}

          workflow = Models::Task.new(
            title: interpolate_vars(plan.title, vars),
            description: interpolate_vars(plan.description, vars),
            type: plan.type,
            priority: plan.priority,
            source_plan_id: plan.id,
            ephemeral: ephemeral
          )
          db.create_task(workflow)
          workflow.append_trace("INSTANTIATED", "from Plan #{plan.id}")
          db.update_task(workflow)

          db.find_plan_tasks(plan_id).each do |step|
            db.create_child_task(workflow.id, {
              title: interpolate_vars(step.title, vars),
              description: interpolate_vars(step.description, vars),
              type: step.type,
              priority: step.priority,
              ephemeral: ephemeral
            })
          end

          mode = ephemeral ? "ephemeral" : "persistent"
          output(workflow.to_h) do
            puts "Created #{mode} Workflow: #{workflow.id}"
          end
        end
      end

      def interpolate_vars(text, vars)
        return text if text.nil? || vars.empty?

        result = text.dup
        vars.each { |key, value| result.gsub!("{{#{key}}}", value.to_s) }
        result
      end

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
