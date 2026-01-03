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

        lines = ["digraph dependencies {"]
        lines << '  rankdir=TB;'
        lines << '  node [shape=box, style=filled];'
        lines << ""

        tasks.each do |task|
          color = node_color(task)
          label = "#{task.id}\\n#{truncate(task.title, 30)}"
          lines << "  \"#{task.id}\" [label=\"#{label}\", fillcolor=\"#{color}\"];"
        end

        lines << ""

        task_set = Set.new(tasks.map(&:id))

        tasks.each do |task|
          @db.find_dependencies(task.id, direction: :outgoing).each do |dep|
            next unless task_set.include?(dep.target_id)

            style = edge_style(dep)
            lines << "  \"#{dep.source_id}\" -> \"#{dep.target_id}\" [#{style}];"
          end
        end

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
        stdout.gsub(/fill="white"/, 'fill="none"')
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

      def build_tree_node(task, direction, remaining_depth, visited)
        return nil if remaining_depth <= 0 || visited.include?(task.id)

        visited << task.id

        node = {
          id: task.id,
          title: task.title,
          status: task.status,
          priority: task.priority,
          children: []
        }

        dep_direction = direction == :blocking ? :incoming : :outgoing
        deps = @db.find_dependencies(task.id, direction: dep_direction)
        deps = deps.select(&:blocking?) if direction == :blocking

        deps.each do |dep|
          related_id = direction == :blocking ? dep.source_id : dep.target_id
          related_task = @db.find_task(related_id)
          next unless related_task

          child_node = build_tree_node(related_task, direction, remaining_depth - 1, visited.dup)
          node[:children] << child_node if child_node
        end

        node
      end

      def collect_related_tasks(start_id, direction, types)
        visited = Set.new
        queue = [start_id]
        result = []

        while queue.any?
          current_id = queue.shift
          next if visited.include?(current_id)

          visited << current_id

          deps = @db.find_dependencies(current_id, direction: direction)
          deps = deps.select { |d| types.include?(d.type) }

          deps.each do |dep|
            related_id = direction == :incoming ? dep.source_id : dep.target_id
            next if visited.include?(related_id)

            task = @db.find_task(related_id)
            if task
              result << task
              queue << related_id
            end
          end
        end

        result
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
          incoming = @db.find_dependencies(task.id, direction: :incoming).count
          outgoing = @db.find_dependencies(task.id, direction: :outgoing).count

          if incoming >= 3 || outgoing >= 3
            bottlenecks << {
              id: task.id,
              title: task.title,
              incoming_deps: incoming,
              outgoing_deps: outgoing
            }
          end
        end

        bottlenecks.sort_by { |b| -(b[:incoming_deps] + b[:outgoing_deps]) }
      end

      def node_color(task)
        status_color = COLORS[:status][task.status.to_sym]
        return status_color if status_color

        priority_colors = {
          0 => COLORS[:priority][:critical],
          1 => COLORS[:priority][:high],
          2 => COLORS[:priority][:medium],
          3 => COLORS[:priority][:low]
        }
        priority_colors[task.priority] || COLORS[:priority][:backlog]
      end

      def edge_style(dep)
        type_key = dep.type.tr("-", "_").to_sym
        color = COLORS[:edge][type_key]
        return "" unless color

        style = case dep.type
                when "blocks" then "bold"
                when "parent-child", "related", "discovered-from" then "dashed"
                else "solid"
                end
        style = "dotted" if %w[related discovered-from].include?(dep.type)

        %(color="#{color}", style=#{style})
      end

      def truncate(str, length)
        return str if str.length <= length

        "#{str[0, length - 3]}..."
      end
    end
  end
end
