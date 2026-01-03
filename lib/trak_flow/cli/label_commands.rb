# frozen_string_literal: true

module TrakFlow
  class CLI < Thor
    # Label subcommands
    class LabelCommands < Thor
      class_option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"

      desc "add ID LABEL", "Add a label to a task"
      def add(id, label_name)
        with_database do |db|
          label = Models::Label.new(task_id: id, name: label_name)
          db.add_label(label)

          output(label.to_h) do
            puts "Added label '#{label_name}' to #{id}"
          end
        end
      end

      desc "remove ID LABEL", "Remove a label from a task"
      def remove(id, label_name)
        with_database do |db|
          count = db.remove_label(id, label_name)

          output({ removed: count }) do
            puts count.positive? ? "Removed label '#{label_name}' from #{id}" : "Label not found"
          end
        end
      end

      desc "list ID", "List labels for a task"
      def list(id)
        with_database do |db|
          labels = db.find_labels(id)

          output(labels.map(&:to_h)) do
            if labels.empty?
              puts "No labels"
            else
              labels.each { |l| puts l.name }
            end
          end
        end
      end

      desc "list-all", "List all labels in the database"
      def list_all
        with_database do |db|
          labels = db.all_labels

          output(labels) do
            if labels.empty?
              puts "No labels"
            else
              labels.each { |l| puts l }
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
