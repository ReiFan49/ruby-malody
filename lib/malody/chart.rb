require 'json'

module Malody
  # Malody chart format, as defined and created from the program itself.
  # For ported charts should be on different file.
  module Chart
    # A module defining an Abstract Class interface.
    module AbstractClass
      def abstract?
        return !!@_abstract unless defined?(@_abstract)
        @_abstract = false
      end
      def abstract_method(name)
        define_method name do |*|
          return unless self.method(__method__).super_method.nil?
          fail NotImplementedError, "Abstract method #{String(name).to_sym} invoked."
        end
      end
      def self.extended(cls)
        cls.instance_variable_set(:@_abstract, true)
        cls.class_exec do
          define_singleton_method :inherited do |subcls|
            subcls.instance_variable_set(:@_abstract, false)
          end
          old_new = method(:new)
          define_singleton_method :new do |*args, **kwargs, &block|
            fail TypeError, "Cannot instantiate from abstract class" if self.abstract?
            obj = self.allocate
            if kwargs.empty? then
              obj.send(:initialize, *args, &block)
            else
              obj.send(:initialize, *args, **kwargs, &block)
            end
            obj
          end
        end
      end
    end
    # interface that defines customizable #inspect output.
    module FriendlyFormattedOutput
      # formats inspect output to be more properly defined on #to_human_format
      # @return [String]
      def inspect
        human_format = to_human_format.map do |k, (v, f)|
          "%%s: %%%s" % [f] % [k, v]
        end.join(' ')
        sprintf("#<%s {%s}>", self.class.name, human_format)
      end
      # obtain friendly format of output formatting
      # denoted by variable followed with a format string
      # @return [Hash<String, Array<Object, String>>]
      def to_human_format
        {beat: [@b, 'd'], dividend: [@n, 'd'], divisor: [@d, 'd']}
      end
    end
    # @abstract A superclass of most time-related entry in Malody Chart Structure.
    class TimeMarkedEntry
      include FriendlyFormattedOutput
      extend AbstractClass
      # Initializes time-tied entry.
      # @param b [Integer] defines beat from first offset.
      # @param n [Integer] defines the dividend of the beat divisor
      # @param d [Integer] defines the beat divisor.
      def initialize(b, n, d)
        @b, @n, @d = b, n, d
      end
      
      attr_reader :b, :n, :d
      
      # checks whether time tuple is equivalent to each other
      # @return [Boolean]
      def same_time?(other)
        return false unless self.b == other.b
        return true if self.n.zero? && other.n.zero?
        self_div = Rational(self.n, self.d)
        other_div = Rational(other.n, other.d)
        self_div == other_div
      end
      # obtain equality of the entry.
      # @return [Boolean]
      def ==(other)
        self.same_time?(other)
      end
      #
      # @return [Hash]
      def to_h
        {beat: [@b, @n, @d]}
      end
    end
    # class that defines TimingPoint entry of a chart.
    class TimeEntry < TimeMarkedEntry
      # @param time [(Integer, Integer, Integer)] defines time tuple of the entry.
      #   formed in beat, numerator, divisor order.
      # @param bpm [Numeric] defines the BPM of time entry
      def initialize(time, bpm)
        super(*time)
        @bpm = bpm
      end
      
      attr_reader :bpm
      
      # obtain equality of the entry.
      # @return [Boolean]
      def ==(other)
        super(other) && self.bpm == other.bpm
      end
      
      # @return [Float] second per beat
      def sec_per_beat; Rational(60, bpm).to_f end
      # @return [Float] millisecond per beat
      def ms_per_beat;  Rational(60000, bpm).to_f end
      # @return [Hash<String, Array<Object, String>>] friendly format inspect output
      def to_human_format
        super.update({bpm: [@bpm, '.3f']})
      end
    end
    class EffectEntry < TimeMarkedEntry
    end
    class NoteEntry < TimeMarkedEntry
    end
    private_constant :AbstractClass
    private_constant :TimeMarkedEntry
    SongMetadata = Struct.new(:artist, :title, :artist_uni, :title_uni)
    # Interface for chart modes that support barline adjustment.
    module ModeSupportBarline
      def initialize_extra(**extra)
        super
        @bar_offset = extra[:bar_begin]
      end
    end
    # @abstract A superclass that defines basic of Malody Charts.
    class Base
      extend AbstractClass
      # @param kwargs [Hash<Symbol, Object>] chart data type.
      # @raise [TypeError] calling from this class directly.
      def initialize(**kwargs)
        [
          [Integer, %i(version preview set_id chart_id time)],
          [String, %i(creator bg name)],
        ].each do |c, v|
          v.each do |x|
            fail KeyError, "key #{String(x).to_sym} is not defined" unless kwargs.key?(x)
            y = kwargs[x]
            next if c === y
            fail TypeError, "expected key #{String(x).to_sym} a #{c}, given #{y.class}"
          end
        end
        @version, @owner, @bg_file, @name, @preview_time = kwargs.values_at(:version, :creator, :bg, :name, :preview)
        @set_id, @chart_id = kwargs.values_at(:set_id, :chart_id)
        @time = Time.at(kwargs[:time])
        @song = SongMetadata.new(*kwargs[:song].values_at(:artist, :title, :artist_unicode, :title_unicode))
        @dummy = kwargs[:extra_dummy]
        initialize_extra(**kwargs[:extra_meta])
      end
      # @abstract defines method to be overriden for initialization
      abstract_method :initialize_extra
      # @abstract defines given class mode ID. only need to be defined under respective sublcass.
      abstract_method :mode
      # @abstract reverses the transformation from Malody Lib to Malody Chart Data.
      # @return [Hash] chart meta extra data.
      def extension_data; {}; end
      # @return [Hash] original format.
      def to_h
        {
          meta: {
            :$ver => @version, creator: @owner, background: @bg_file, version: @name,
            preview: @preview_time, id: @chart_id, mode: self.mode, time: @time.to_i,
            song: @song.convert_to_hash(@set_id), mode_ext: self.extension_data,
          },
          time: [],
          effect: [],
          note: [],
          extra: @dummy,
        }
      end
      class << self
        def timing_effect_class; EffectEntry; end
        def note_object_class; NoteEntry; end
      end
    end
    # Key mode namespace definition of library.
    module Key
      # Key Chart Data
      class Data < Base
        include ModeSupportBarline
        
        def initialize_extra(**extra)
          super
          @keys = extra[:column]
        end
        
        def mode; Mode::Key end
        attr_reader :keys
        
        def extension_data; {column: @keys}; end
        
        class << self
          def timing_effect_class; Effect; end
          def note_object_class; Note; end
        end
      end
      # Key Effect Data
      class Effect < EffectEntry
      end
      # Key Note Data
      class Note < NoteEntry
      end
    end
    # @overload load(io)
    #   Loads given data to be parsed by Malody Chart Parser.
    #   Given data must form JSON by any means.
    #   @param io [#read] given string IO that supports reading.
    # @overload load(fn)
    #   @param fn [String] pass filename to process
    #   @note Given filename must be a file that contains JSON format.
    # @overload load(hash)
    #   @param hash [Hash] a JSON dictionary.
    #   @see #parse You should use this instead.
    # @return [Base] malody chart data.
    def self.load(io)
      return parse(JSON.parse(io.read, symbolize_names: true)) if io.respond_to?(:read)
      case io
      when String
        parse(JSON.parse(io, symbolize_names: true))
      when Hash
        parse(io)
      end
    end
    # Parse given dictionary data into a readable Malody library data.
    # @param json [Hash] object that is returned from JSON.parse method.
    # @return [Base] malody chart data.
    # @raise [NotImplementedError] Unsupported or Not yet implemented data will raise this error.
    def self.parse(json)
      mode_id = json.dig(:meta,:mode)
      mode_kv = Malody::Mode.constants.map do |k| [k, Malody::Mode.const_get(k)] end
      fail NotImplementedError, "Unsupported Mode ID #{mode_id}" unless mode_kv.map(&:last).include?(mode_id)
      mode_t = mode_kv.find do |k,v| v == mode_id end
      fail NotImplementedError, "Namespace #{mode_t[0]} not defined yet." unless Chart.const_defined?(mode_t[0])
      ns = Chart.const_get(mode_t[0])
      j_meta, j_time, j_eff, j_note, j_editor = json.values_at(:meta, :time, :effect, :note, :extra)
      sid, cid = json.dig(:meta, :song, :id), json.dig(:meta, :id)
      mapper = {
        meta: {
          version: :$ver, creator: :creator, bg: :background, name: :version, time: :time,
          preview: :preview, extra_meta: :mode_ext,
        },
        'meta.song': {'song.artist': :artist, 'song.artist_unicode': :artistorg, 'song.title': :title, 'song.title_unicode': :titleorg},
      }
      m = {set_id: sid, chart_id: cid}
      mapper.each do |k, ct|
        kfi = []
        if String(k).include?('.') then
          kfi.concat(String(k).split('.').map(&:to_sym))
        else
          kfi.push(k)
        end
        m[kfi.first] = ch = {}
        if kfi.length > 1 && m.dig(*kfi[0...-1]).nil?
          kfi.size.times do |i|
            ch[kfi[i]] ||= {}
            ch = ch[kfi[i]]
          end
        end
        ch = json.dig(*kfi)
        ct.each do |tk, fk|
          tkfi = []
          if String(tk).include?('.') then
            tkfi.concat(String(tk).split('.').map(&:to_sym))
          else
            tkfi.push(tk)
          end
          cm = m
          while tkfi.size > 1
            ntk = tkfi.shift
            cm[ntk] ||= {}
            cm = cm[ntk]
          end
          cm[tkfi.last] = ch[fk]
        end
      end
      m[:extra_dummy] = json[:extra]
      p m
      ns::Data.new(**m)
    end
  end
end
