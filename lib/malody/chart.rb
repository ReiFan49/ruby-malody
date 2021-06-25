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
          # old_new = method(:new)
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
      include Comparable
      include FriendlyFormattedOutput
      extend AbstractClass
      # Initializes time-tied entry.
      # @param b [Integer] defines beat from first offset.
      # @param n [Integer] defines the dividend of the beat divisor
      # @param d [Integer] defines the beat divisor.
      def initialize(b, n, d)
        fail RangeError, "Denominator must be a positive integer." unless Integer === d && d.positive?
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
      # Compare against other TimeMarkedEntry object.
      # @return [Integer, nil]
      def <=>(other)
        return if self.class != other.class
        return if self.d.nil? || other.d.nil?
        (self.b <=> other.b).nonzero? ||
          (Rational(self.n, self.d) <=> Rational(other.n, other.d))
      end
      
      # @return [Hash] JSON definition of the object
      # @see #to_json
      def to_h; to_json; end
      # @return [Hash]
      def to_json(*)
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
    # class defining effect given to the chart
    class EffectEntry < TimeMarkedEntry
      def initialize(beat:, **kwargs)
        super(*beat)
      end
    end
    # class defining basic of command entry
    class CommandEntry < TimeMarkedEntry
      def initialize(beat:, **kwargs)
        super(*beat)
      end
      # Compare against other TimeMarkedEntry object.
      # @return [Integer, nil]
      def <=>(other)
        return unless self.class <= CommandEntry
        return if self.d.nil? || other.d.nil?
        (self.b <=> other.b).nonzero? ||
          (Rational(self.n, self.d) <=> Rational(other.n, other.d))
      end
    end
    # class defining note object command entry
    class NoteEntry < CommandEntry
      #def initialize(**kwargs)
      #  super(**kwargs)
      #end
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
        initialize_meta(**kwargs[:meta])
        initialize_timing(kwargs[:timing])
        initialize_effect(kwargs[:effect])
        initialize_object(kwargs[:object])
        initialize_extra(**kwargs[:extra_meta])
        @dummy = kwargs[:extra_dummy]
        [@timings, @effects, @objects].each(&:sort!)
      end
      # Initializes chart header
      # @return [void]
      def initialize_meta(**kwargs)
        key_violation = {miss:[], diff:[]}
        [
          [Integer, %i(version preview set_id chart_id time)],
          [String, %i(creator bg name)],
        ].each do |c, v|
          v.each do |x|
            next key_violation[:miss].push(x) unless kwargs.key?(x)
            y = kwargs[x]
            next if c === y
            key_violation[:diff].push([x,c,y.class])
          end
        end
        key_violation[:miss].tap do |kv|
          next if kv.empty?
          fail KeyError, "key #{kv.join(', ')} is not defined"
        end
        key_violation[:diff].tap do |kv|
          next if kv.empty?
          err_str = kv.group_by do |e| e[1] end.map do |c, el|
            out_str = el.map do |k, c, cx| "%s (given %s)" % [k, cx] end.join(', ')
            "on %s, expected %s" % [out_str, c]
          end.join('; ')
          fail TypeError, err_str
        end
        @version, @owner, @bg_file, @name, @preview_time = kwargs.values_at(:version, :creator, :bg, :name, :preview)
        @set_id, @chart_id = kwargs.values_at(:set_id, :chart_id)
        @time = Time.at(kwargs[:time])
        @song = SongMetadata.new(*kwargs[:song].values_at(:artist, :title, :artist_unicode, :title_unicode))
      end
      # Initializes chart timing
      # @return [void]
      def initialize_timing(timings)
        @timings = []
        timings.each do |obj|
          @timings << TimeEntry.new(obj[:beat], obj[:bpm])
        end
      end
      # Initializes chart effects
      # @return [void]
      def initialize_effect(effects)
        @effects = []
        effects.each do |obj|
          @effects << self.class.timing_class.new(**obj)
        end
      end
      # Initializes chart objects
      # @return [void]
      def initialize_object(objects)
        @objects = []
        objects.each do |obj|
          # {"beat":[0,0,1],"sound":"hiska13.ogg","vol":100,"offset":211,"type":1}
          if obj.key?(:sound) && obj.key?(:offset) then
            @objects.push CommandEntry.new(**obj)
          else
            @objects.push self.class.note_class.new(**obj)
          end
        end
      end
      # @abstract defines method to be overriden for initialization
      abstract_method :initialize_extra
      public
      
      # @abstract defines given class mode ID. only need to be defined under respective sublcass.
      abstract_method :mode
      # @abstract reverses the transformation from Malody Lib to Malody Chart Data.
      # @return [Hash] chart meta extra data.
      def extension_data; {}; end
      # @return [Hash] JSON definition of the object
      # @see #to_json
      def to_h; to_json; end
      # @return [Hash] original format.
      def to_json(*)
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
        def timing_class; EffectEntry; end
        def note_class; NoteEntry; end
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
          def timing_class; Effect; end
          def note_class; Note; end
        end
      end
      # Key Effect Data
      class Effect < EffectEntry
      end
      # Key Note Data
      class Note < NoteEntry
      end
    end
    ObjectSpace.each_object(Class) do |c|
      next unless c <= Base
      c.send(:private, *c.instance_methods.select do |m| String(m).start_with?('initialize_') end)
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
          version: :$ver, creator: :creator, bg: :background,
          name: :version, time: :time, preview: :preview,
        },
        'meta.song': {'song.artist': :artist, 'song.artist_unicode': :artistorg, 'song.title': :title, 'song.title_unicode': :titleorg},
      }
      me = {set_id: sid, chart_id: cid}
      ma = {meta: me, timing: [], effect: [], object: [], extra_meta: nil, extra_dummy: []}
      mapper.each do |k, ct|
        kfi = []
        if String(k).include?('.') then
          kfi.concat(String(k).split('.').map(&:to_sym))
        else
          kfi.push(k)
        end
        kfi.shift
        ch = kfi.empty? ? j_meta : j_meta.dig(*kfi)
        ct.each do |tk, fk|
          tkfi = []
          if String(tk).include?('.') then
            tkfi.concat(String(tk).split('.').map(&:to_sym))
          else
            tkfi.push(tk)
          end
          cm = me
          while tkfi.size > 1
            ntk = tkfi.shift
            cm[ntk] ||= {}
            cm = cm[ntk]
          end
          cm[tkfi.last] = ch[fk]
        end
      end
      ma[:timing] = j_time
      ma[:effect] = j_eff
      ma[:object] = j_note
      ma[:extra_meta] = json.dig(:meta,:mode_ext)
      ma[:extra_dummy] = j_editor
      ns::Data.new(**ma)
    end
  end
end
