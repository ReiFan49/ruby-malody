module Malody
  # Defining mode constants throughout the game data.
  module Mode
    Key   = 0
    Catch = 3
    Pad   = 4
    Taiko = 5
    Ring  = 6
    Slide = 7
    Live  = 8
    
    # Obtain mode bit value
    # @return [Integer]
    def self.get_bit(value)
      case value
      when Symbol
        return unless self.constants.include?(value)
        1 << self.const_get(value)
      when Integer
        return if value.negative?
        1 << value
      end
    end
    
    # Obtain combined mode bit values
    # @return [Integer]
    def self.get_mode_value(*values)
      return if values.empty?
      bits = values.map do |value| self.get_bit value end.compact
      return if bits.empty?
      bits.reduce(0, :|)
    end
    
    # Obtain supported mode from given bit values.
    # @return [Array<Symbol>]
    def self.get_modes(value)
      self.constants.select do |mode|
        mode_value = 1 << self.const_get(mode)
        (value & mode_value).nonzero?
      end
    end
  end
  
end
