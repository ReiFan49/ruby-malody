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
    def self.get_bit(value)
      case value
      when Symbol
        return unless self.constants.include?(value)
        1 << self.const_get(value)
      when Integer
        return 1 << value
      end
    end
    
    # Obtain combined mode bit values
    def self.get_modes(*values)
      return if values.empty?
      bits = values.map do |value| self.get_bit value end.compact
      return if bits.empty?
      bits.reduce(0, :|)
    end
  end
    
end
