# frozen_string_literal: true

module TrakFlow
  class CLI < Thor
    # NOTE: class_option :json is defined in main_commands.rb, NOT here.
    # This prevents Thor from consuming -j before routing to subcommands.

    no_commands do
      def json?
        options[:json]
      end

      def pastel
        @pastel ||= Pastel.new
      end

      def output_json(data)
        puts Oj.dump(data, mode: :compat, indent: 2)
      end

      def output(json_data, &human_block)
        if json?
          output_json(json_data)
        else
          human_block.call
        end
      end

      def with_database
        TrakFlow.ensure_initialized!

        db = Storage::Database.new
        db.connect

        jsonl = Storage::Jsonl.new
        jsonl.import(db) if jsonl.exists?

        yield db

        jsonl.export(db) if db.dirty?
      ensure
        db&.close
      end

      def colorize_status(status)
        case status
        when "open" then pastel.green(status)
        when "in_progress" then pastel.blue(status)
        when "blocked" then pastel.red(status)
        when "deferred" then pastel.yellow(status)
        when "closed" then pastel.dim(status)
        when "tombstone" then pastel.dim.strikethrough(status)
        when "pinned" then pastel.magenta(status)
        else status
        end
      end

      def colorize_priority(priority)
        case priority
        when 0 then pastel.red.bold("P0 (critical)")
        when 1 then pastel.red("P1 (high)")
        when 2 then pastel.yellow("P2 (medium)")
        when 3 then pastel.blue("P3 (low)")
        when 4 then pastel.dim("P4 (backlog)")
        else "P#{priority}"
        end
      end

      def print_tasks_table(tasks)
        table = TTY::Table.new(
          header: %w[ID Priority Status Type Title],
          rows: tasks.map do |task|
            [
              task.id,
              "P#{task.priority}",
              task.status,
              task.type,
              truncate(task.title, 50)
            ]
          end
        )
        puts table.render(:unicode, padding: [0, 1])
      end

      def truncate(str, length)
        return str if str.nil? || str.length <= length

        "#{str[0, length - 3]}..."
      end

      def status_icon(status)
        case status
        when "closed" then "[x]"
        when "in_progress" then "[~]"
        when "blocked" then "[!]"
        else "[ ]"
        end
      end
    end
  end
end

# Load subcommand classes first (main_commands references them)
require_relative "cli/dep_commands"
require_relative "cli/label_commands"
require_relative "cli/plan_commands"
require_relative "cli/workflow_commands"
require_relative "cli/admin_commands"
require_relative "cli/main_commands"
