# frozen_string_literal: true

require "bundler/setup"

# SimpleCov must be loaded before application code
require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  add_group "Config", "lib/trak_flow/config"
  add_group "Models", "lib/trak_flow/models"
  add_group "Storage", "lib/trak_flow/storage"
  add_group "Graph", "lib/trak_flow/graph"
end

require "minitest/autorun"
require "minitest/reporters"
require "fileutils"
require "tmpdir"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require "trak_flow"

module TrakFlowTestHelper
  def setup
    @test_dir = Dir.mktmpdir("trak_flow_test")
    @original_dir = Dir.pwd
    Dir.chdir(@test_dir)
    TrakFlow.reset_root!
    TrakFlow.reset_config!
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  def init_trak_flow
    trak_flow_dir = File.join(@test_dir, ".trak_flow")
    FileUtils.mkdir_p(trak_flow_dir)

    # Configure database path to use test directory
    db_path = File.join(trak_flow_dir, "trak_flow.db")
    TrakFlow.config.database.path = db_path

    db = TrakFlow::Storage::Database.new(db_path)
    db.connect
    db
  end
end
