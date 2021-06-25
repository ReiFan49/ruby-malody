require "test_helper"
require 'pathname'

class MalodyTest < Minitest::Test
  def obtain_chart_files
    # had to use something like this because
    # glob will screw up if found any meta characters such as
    # brackets.
    base_dir = Pathname.new(__dir__).relative_path_from(Dir.pwd).to_s
    Dir["#{base_dir}/files/**/*.{mc}"]
  end
  
  def test_that_it_has_a_version_number
    refute_nil ::Malody::VERSION
  end
  
  def test_constants_mode_bit_existence
    ::Malody::Mode.constants.each do |mode|
      refute_nil ::Malody::Mode.get_bit(mode), "None of the constants should be invalid."
    end
  end
  
  def test_constants_mode_bit_combination
    3.times.each do |j|
      6.times.each do |i|
        if i < 3 then
          min_mode, max_mode = 2, 4
        else
          min_mode, max_mode = 3, 6
        end
        modes = ::Malody::Mode.constants.sample(rand(min_mode..max_mode))
        conv_index = (0...modes.size).to_a.sample(modes.size * j / 2)
        conv_index.each do |idx| modes[idx] = ::Malody::Mode.const_get(modes[idx]) end
        bits = modes.map do |mode| Symbol === mode ? ::Malody::Mode.get_bit(mode) : (1 << mode) end
        mode_sum = bits.inject(0, :+)
        mode_value = ::Malody::Mode.get_mode_value(*modes)
        refute_nil mode_value, "Empty modes are not supposed to be allowed."
        assert_equal mode_sum, mode_value, "Bits are expected to add each other as well."
      end
    end
  end
  
  def test_constants_mode_symbols
    7.times.each do |i|
      mode_name  = ::Malody::Mode.constants
      if i.zero? then
        mode_sel   = Set.new(mode_name)
        mode_value = -1
      else
        mode_sel   = Set.new(mode_name.sample(rand((mode_name.size / 3)...(mode_name.size))))
        mode_value = ::Malody::Mode.get_mode_value(*mode_sel)
      end
      mode_sel2 = Set.new(::Malody::Mode.get_modes(mode_value))
      assert_equal mode_sel, mode_sel2, "Given mode value should return back to its own"
    end
  end
  
  def test_undefined_modes
    modes = Malody::Mode.constants
    undefined_modes = modes - Malody::Chart.constants
    undefined_ids = undefined_modes.map do |mode| Malody::Mode.const_get(mode) end
    skip "All modes are defined properly. No need this test." if undefined_modes.empty?
    chart_processed = 0
    obtain_chart_files.each do |file|
      json = JSON.parse(File.read(file), symbolize_names: true)
      next unless undefined_ids.include?(json.dig(:meta, :mode))
      chart_processed += 1
      assert_raises NotImplementedError, "Mode #{json.dig(:meta, :mode)} shouldn't be implemented yet." do
        Malody::Chart.parse(json)
      end
    end
    skip "No unsupported charts available to process." if chart_processed.zero?
  end
  
  def test_defined_modes
    modes = Malody::Mode.constants
    defined_modes = modes & Malody::Chart.constants
    defined_ids = defined_modes.map do |mode| Malody::Mode.const_get(mode) end
    refute_empty defined_modes, "No modes defined yet."
    chart_processed = 0
    obtain_chart_files.each do |file|
      json = JSON.parse(File.read(file), symbolize_names: true)
      next unless defined_ids.include?(json.dig(:meta, :mode))
      chart_processed += 1
      chart = Malody::Chart.parse(json)
      p chart
    end
    refute_predicate chart_processed, :zero?, "No unsupported charts available to process."
  end
end
