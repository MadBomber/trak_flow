# frozen_string_literal: true

module TrakFlow
  module Graph
    # Dependency graph operations for visualizing and analyzing task relationships
    class DependencyGraph
      # Graph visualization colors (dark theme compatible)
      COLORS = {
        status: {
          closed: "#4a5568",
          tombstone: "#4a5568",
          in_progress: "#3182ce",
          blocked: "#e53e3e",
          deferred: "#d69e2e",
          pinned: "#805ad5"
        },
        priority: {
          critical: "#e53e3e",
          high: "#ed8936",
          medium: "#48bb78",
          low: "#4299e1",
          backlog: "#a0aec0"
        },
        edge: {
          blocks: "#e53e3e",
          parent_child: "#3182ce",
          related: "#a0aec0",
          discovered_from: "#805ad5"
        }
      }.freeze

      def initialize(db)
        @db = db
      end

      # Build a tree representation of dependencies for a task
      def dependency_tree(task_id, direction: :blocking, max_depth: 10)
        task = @db.find_task!(task_id)
        build_tree_node(task, direction, max_depth, Set.new)
      end

      # Find all tasks that block the given task (directly or transitively)
      def all_blockers(task_id)
        collect_related_tasks(task_id, :incoming, Models::Dependency::BLOCKING_TYPES)
      end

      # Find all tasks blocked by the given task (directly or transitively)
      def all_blocked(task_id)
        collect_related_tasks(task_id, :outgoing, Models::Dependency::BLOCKING_TYPES)
      end

      # Find the critical path - longest chain of blocking dependencies
      def critical_path(root_task_id)
        visited = {}
        find_longest_path(root_task_id, visited)
      end

      # Get all leaf tasks (tasks with no children/blocked tasks)
      def leaf_tasks
        all_targets = Set.new

        @db.all_task_ids.each do |id|
          @db.find_dependencies(id, direction: :outgoing).each do |dep|
            all_targets << dep.target_id if dep.blocking?
          end
        end

        @db.list_tasks.reject { |task| all_targets.include?(task.id) }
      end

      # Get all root tasks (tasks with no parents/blockers)
      def root_tasks
        all_sources = Set.new

        @db.all_task_ids.each do |id|
          @db.find_dependencies(id, direction: :incoming).each do |dep|
            all_sources << dep.source_id if dep.blocking?
          end
        end

        @db.list_tasks.reject { |task| all_sources.include?(task.id) }
      end

      # Generate a DOT representation for Graphviz
      def to_dot(task_ids: nil, include_closed: false)
        task_ids ||= @db.all_task_ids
        tasks = task_ids.map { |id| @db.find_task(id) }.compact
        tasks = tasks.reject(&:closed?) unless include_closed

        lines = ["digraph dependencies {", "  rankdir=TB;", "  node [shape=box, style=filled];", ""]
        lines.concat(dot_node_lines(tasks))
        lines << ""
        lines.concat(dot_edge_lines(tasks))
        lines << "}"
        lines.join("\n")
      end

      # Generate SVG using Graphviz (if available)
      def to_svg(task_ids: nil, include_closed: false)
        dot = to_dot(task_ids: task_ids, include_closed: include_closed)

        require "open3"
        stdout, stderr, status = Open3.capture3("dot", "-Tsvg", stdin_data: dot)

        unless status.success?
          raise Error, "Graphviz error: #{stderr}"
        end

        # Make background transparent for dark theme compatibility
        stdout.gsub('fill="white"', 'fill="none"')
      end

      # Analyze the graph for potential problems
      def analyze
        {
          total_tasks: @db.all_task_ids.size,
          open_tasks: @db.list_tasks(status: "open").size,
          ready_tasks: @db.ready_tasks.size,
          blocked_tasks: @db.blocked_tasks.size,
          orphan_tasks: find_orphans.size,
          potential_cycles: find_potential_bottlenecks
        }
      end

      private

      def dot_node_lines(tasks)
        tasks.map do |task|
          id = task.id
          label = "#{id}\\n#{truncate(task.title, 30)}"
          "  \"#{id}\" [label=\"#{label}\", fillcolor=\"#{node_color(task)}\"];"
        end
      end

      # Edges are drawn only between tasks that are both in the graph.
      def dot_edge_lines(tasks)
        task_set = Set.new(tasks.map(&:id))

        tasks.flat_map do |task|
          @db.find_dependencies(task.id, direction: :outgoing)
             .select { |dep| task_set.include?(dep.target_id) }
             .map { |dep| "  \"#{dep.source_id}\" -> \"#{dep.target_id}\" [#{edge_style(dep)}];" }
        end
      end

      def build_tree_node(task, direction, remaining_depth, visited)
        task_id = task.id
        return nil if remaining_depth <= 0 || visited.include?(task_id)

        visited << task_id

        node = {
          id: task_id,
          title: task.title,
          status: task.status,
          priority: task.priority,
          children: []
        }

        related_tasks(task_id, direction).each do |related_task|
          child_node = build_tree_node(related_task, direction, remaining_depth - 1, visited.dup)
          node[:children] << child_node if child_node
        end

        node
      end

      # Tasks one dependency hop away from task_id. In :blocking direction only
      # blocking incoming deps count; otherwise all outgoing deps do.
      def related_tasks(task_id, direction)
        blocking = direction == :blocking
        deps = @db.find_dependencies(task_id, direction: blocking ? :incoming : :outgoing)
        deps = deps.select(&:blocking?) if blocking

        deps.filter_map { |dep| @db.find_task(blocking ? dep.source_id : dep.target_id) }
      end

      def collect_related_tasks(start_id, direction, types)
        visited = Set.new
        queue = [start_id]
        result = []

        while queue.any?
          current_id = queue.shift
          next if visited.include?(current_id)

          visited << current_id

          unvisited_related_tasks(current_id, direction, types, visited).each do |task|
            result << task
            queue << task.id
          end
        end

        result
      end

      def unvisited_related_tasks(current_id, direction, types, visited)
        @db.find_dependencies(current_id, direction: direction)
           .select { |d| types.include?(d.type) }
           .filter_map do |dep|
             related_id = direction == :incoming ? dep.source_id : dep.target_id
             @db.find_task(related_id) unless visited.include?(related_id)
           end
      end

      def find_longest_path(task_id, memo)
        return memo[task_id] if memo.key?(task_id)

        task = @db.find_task(task_id)
        return [] unless task

        deps = @db.find_dependencies(task_id, direction: :outgoing)
        blocking_deps = deps.select(&:blocking?)

        if blocking_deps.empty?
          memo[task_id] = [task]
          return [task]
        end

        longest_child_path = blocking_deps.map do |dep|
          find_longest_path(dep.target_id, memo)
        end.max_by(&:size) || []

        memo[task_id] = [task] + longest_child_path
        memo[task_id]
      end

      def find_orphans
        @db.list_tasks.select do |task|
          task.parent_id && !@db.find_task(task.parent_id)
        end
      end

      def find_potential_bottlenecks
        bottlenecks = []

        @db.list_tasks(status: "open").each do |task|
          id = task.id
          incoming = @db.find_dependencies(id, direction: :incoming).count
          outgoing = @db.find_dependencies(id, direction: :outgoing).count

          next unless incoming >= 3 || outgoing >= 3
          bottlenecks << {
            id: id,
            title: task.title,
            incoming_deps: incoming,
            outgoing_deps: outgoing
          }
        end

        bottlenecks.sort_by { |b| -(b[:incoming_deps] + b[:outgoing_deps]) }
      end

      def node_color(task)
        status_color = COLORS[:status][task.status.to_sym]
        return status_color if status_color

        priorities = COLORS[:priority]
        priority_colors = {
          0 => priorities[:critical],
          1 => priorities[:high],
          2 => priorities[:medium],
          3 => priorities[:low]
        }
        priority_colors[task.priority] || priorities[:backlog]
      end

      def edge_style(dep)
        type = dep.type
        color = COLORS[:edge][type.tr("-", "_").to_sym]
        return "" unless color

        style = case type
                when "blocks" then "bold"
                when "parent-child" then "dashed"
                when "related", "discovered-from" then "dotted"
                else "solid"
                end

        %(color="#{color}", style=#{style})
      end

      def truncate(str, length)
        return str if str.length <= length

        "#{str[0, length - 3]}..."
      end
    end
  end
end
