# frozen_string_literal: true

require_relative "../test_helper"

class ConfigSectionTest < Minitest::Test
  def setup
    @section = TrakFlow::ConfigSection.new(
      host: "localhost",
      port: 5432,
      nested: { enabled: true, timeout: 30 }
    )
  end

  # ==========================================================================
  # initialize
  # ==========================================================================

  def test_initialize_with_hash
    section = TrakFlow::ConfigSection.new(foo: "bar")
    assert_equal "bar", section.foo
  end

  def test_initialize_with_empty_hash
    section = TrakFlow::ConfigSection.new({})
    assert_equal [], section.keys
  end

  def test_initialize_with_nil
    section = TrakFlow::ConfigSection.new(nil)
    assert_equal [], section.keys
  end

  def test_initialize_with_no_arguments
    section = TrakFlow::ConfigSection.new
    assert_equal [], section.keys
  end

  def test_initialize_converts_string_keys_to_symbols
    section = TrakFlow::ConfigSection.new("string_key" => "value")
    assert_equal "value", section.string_key
  end

  def test_initialize_recursively_converts_nested_hashes
    section = TrakFlow::ConfigSection.new(outer: { inner: { deep: "value" } })
    assert_instance_of TrakFlow::ConfigSection, section.outer
    assert_instance_of TrakFlow::ConfigSection, section.outer.inner
    assert_equal "value", section.outer.inner.deep
  end

  # ==========================================================================
  # Dynamic attribute access (method_missing)
  # ==========================================================================

  def test_read_existing_attribute
    assert_equal "localhost", @section.host
  end

  def test_read_nonexistent_attribute_returns_nil
    assert_nil @section.nonexistent
  end

  def test_write_attribute_via_setter
    @section.host = "newhost"
    assert_equal "newhost", @section.host
  end

  def test_write_new_attribute_via_setter
    @section.new_attr = "new_value"
    assert_equal "new_value", @section.new_attr
  end

  def test_read_nested_section
    assert_instance_of TrakFlow::ConfigSection, @section.nested
    assert_equal true, @section.nested.enabled
    assert_equal 30, @section.nested.timeout
  end

  # ==========================================================================
  # respond_to_missing?
  # ==========================================================================

  def test_respond_to_existing_attribute
    assert @section.respond_to?(:host)
  end

  def test_respond_to_setter_for_existing_attribute
    assert @section.respond_to?(:host=)
  end

  def test_respond_to_nonexistent_attribute
    refute @section.respond_to?(:nonexistent)
  end

  # ==========================================================================
  # to_h
  # ==========================================================================

  def test_to_h_returns_hash
    result = @section.to_h
    assert_instance_of Hash, result
  end

  def test_to_h_contains_all_keys
    result = @section.to_h
    assert_equal %i[host port nested].sort, result.keys.sort
  end

  def test_to_h_recursively_converts_nested_sections
    result = @section.to_h
    assert_instance_of Hash, result[:nested]
    assert_equal({ enabled: true, timeout: 30 }, result[:nested])
  end

  # ==========================================================================
  # [] and []=
  # ==========================================================================

  def test_bracket_read_with_symbol
    assert_equal "localhost", @section[:host]
  end

  def test_bracket_read_with_string
    assert_equal "localhost", @section["host"]
  end

  def test_bracket_read_nonexistent_returns_nil
    assert_nil @section[:nonexistent]
  end

  def test_bracket_write_with_symbol
    @section[:host] = "newhost"
    assert_equal "newhost", @section[:host]
  end

  def test_bracket_write_with_string
    @section["host"] = "anotherhost"
    assert_equal "anotherhost", @section[:host]
  end

  # ==========================================================================
  # merge
  # ==========================================================================

  def test_merge_with_hash
    merged = @section.merge(port: 9999, new_key: "new_value")
    assert_equal 9999, merged.port
    assert_equal "new_value", merged.new_key
    assert_equal "localhost", merged.host
  end

  def test_merge_with_config_section
    other = TrakFlow::ConfigSection.new(port: 8080)
    merged = @section.merge(other)
    assert_equal 8080, merged.port
    assert_equal "localhost", merged.host
  end

  def test_merge_does_not_mutate_original
    original_port = @section.port
    @section.merge(port: 9999)
    assert_equal original_port, @section.port
  end

  def test_merge_with_nil
    merged = @section.merge(nil)
    assert_equal @section.to_h, merged.to_h
  end

  def test_merge_deep_merges_nested_hashes
    section = TrakFlow::ConfigSection.new(
      outer: { a: 1, b: 2 }
    )
    merged = section.merge(outer: { b: 99, c: 3 })
    assert_equal 1, merged.outer.a
    assert_equal 99, merged.outer.b
    assert_equal 3, merged.outer.c
  end

  # ==========================================================================
  # keys
  # ==========================================================================

  def test_keys_returns_all_keys
    assert_equal %i[host port nested].sort, @section.keys.sort
  end

  def test_keys_returns_empty_array_for_empty_section
    section = TrakFlow::ConfigSection.new
    assert_equal [], section.keys
  end

  # ==========================================================================
  # each
  # ==========================================================================

  def test_each_iterates_over_all_pairs
    pairs = []
    @section.each { |k, v| pairs << [k, v] }
    assert_equal 3, pairs.size
    assert pairs.any? { |k, v| k == :host && v == "localhost" }
  end

  def test_each_returns_enumerator_without_block
    assert_instance_of Enumerator, @section.each
  end
end
