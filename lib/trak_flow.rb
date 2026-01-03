# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "securerandom"
require "set"
require "time"

require "oj"
require "sequel"
require "sqlite3"
require "thor"
require "pastel"
require "tty-table"
require "debug_me"
require "anyway_config"

module TrakFlow
  class Error < StandardError; end
  class NotInitializedError < Error; end
  class TaskNotFoundError < Error; end
  class DependencyCycleError < Error; end
  class ValidationError < Error; end
  class ConfigurationError < Error; end

  TRAK_FLOW_DIR = ".trak_flow"
  DATABASE_FILE = "trak_flow.db"
  JSONL_FILE = "issues.jsonl"
  CONFIG_FILE = "config.yml"

  STATUSES = %w[open in_progress blocked deferred closed tombstone pinned].freeze
  PRIORITIES = (0..4).to_a.freeze
  TYPES = %w[bug feature task epic chore].freeze
  DEPENDENCY_TYPES = %w[blocks related parent-child discovered-from].freeze

  class << self
    def root
      @root ||= find_root
    end

    def trak_flow_dir
      File.join(root, TRAK_FLOW_DIR)
    end

    def database_path
      path = config.database.path
      File.expand_path(path)
    end

    def jsonl_path
      File.join(trak_flow_dir, JSONL_FILE)
    end

    def config_path
      File.join(trak_flow_dir, CONFIG_FILE)
    end

    def initialized?
      File.directory?(trak_flow_dir) && File.exist?(database_path)
    end

    def ensure_initialized!
      raise NotInitializedError, "TrakFlow not initialized. Run 'tf init' first." unless initialized?
    end

    def reset_root!
      @root = nil
    end

    private

    def find_root(start_dir = Dir.pwd)
      dir = start_dir
      loop do
        trak_flow_path = File.join(dir, TRAK_FLOW_DIR)
        return dir if File.directory?(trak_flow_path)

        parent = File.dirname(dir)
        return start_dir if parent == dir

        dir = parent
      end
    end
  end
end

require_relative "trak_flow/version"
require_relative "trak_flow/id_generator"
require_relative "trak_flow/time_parser"
require_relative "trak_flow/config"
require_relative "trak_flow/models/task"
require_relative "trak_flow/models/dependency"
require_relative "trak_flow/models/label"
require_relative "trak_flow/models/comment"
require_relative "trak_flow/storage/database"
require_relative "trak_flow/storage/jsonl"
require_relative "trak_flow/graph/dependency_graph"
require_relative "trak_flow/cli"
