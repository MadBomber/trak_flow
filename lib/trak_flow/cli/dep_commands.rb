# frozen_string_literal: true

module TrakFlow
  class CLI < Thor
    # Dependency subcommands
    class DepCommands < Thor
      class_option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"

      desc "add SOURCE TARGET", "Add a dependency"
      option :type, aliases: "-t", type: :string, default: "blocks", desc: "Dependency type"
      def add(source, target)
        with_database do |db|
          dep = Models::Dependency.new(
            source_id: source,
            target_id: target,
            type: options[:type]
          )
          db.add_dependency(dep)

          output(dep.to_h) do
            puts "Added dependency: #{source} #{options[:type]} #{target}"
          end
        end
      end

      desc "remove SOURCE TARGET", "Remove a dependency"
      option :type, aliases: "-t", type: :string, desc: "Dependency type"
      def remove(source, target)
        with_database do |db|
          count = db.remove_dependency(source, target, type: options[:type])

          output({ removed: count }) do
            puts "Removed #{count} dependency(ies)"
          end
        end
      end

      desc "tree ID", "Show dependency tree"
      def tree(id)
        with_database do |db|
          graph = Graph::DependencyGraph.new(db)
          tree_data = graph.dependency_tree(id)

          output(tree_data) do
            print_tree(tree_data, 0)
          end
        end
      end

      private

      def print_tree(node, depth)
        indent = "  " * depth
        puts "#{indent}#{status_icon(node[:status])} #{node[:id]}: #{node[:title]}"
        node[:children].each { |child| print_tree(child, depth + 1) }
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
