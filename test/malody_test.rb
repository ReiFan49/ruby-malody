require "test_helper"

class MalodyTest < Minitest::Test
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
end
