require "set"

# Get us `SmartHash::Loose`. It's usually `Dir[]` in other gems, but we've only got 1 file at the moment.
require File.expand_path("../smart_hash/loose", __FILE__)

# == A smarter alternative to OpenStruct
#
# Major features:
#
# * You can access attributes as methods or keys.
# * Attribute access is strict by default.
# * You can use <b>any</b> attribute names.
# * Descends from `Hash` and inherits its rich feature set.
#
# See {rubydoc documentation}[http://rubydoc.info/github/dadooda/smart_hash/master/frames] for basic usage examples.
class SmartHash < Hash
  # Attribute name regexp without delimiters.
  ATTR_REGEXP = /[a-zA-Z_]\w*/

  # Attribute names that are forbidden.
  # Forbidden attrs cannot be manupulated as such and are handled as methods only.
  FORBIDDEN_ATTRS = [:default, :default_proc, :strict]

  # Gem version.
  VERSION = "0.1.0"

  # See #declare.
  attr_reader :declared_attrs

  # See #protect.
  attr_reader :protected_attrs

  # Strict mode. Default is <tt>true</tt>.
  #
  #   person = SmartHash[]
  #   person.invalid_stuff    # KeyError: key not found: :invalid_stuff
  #
  #   person.strict = false
  #   person.invalid_stuff    # => nil
  attr_accessor :strict

  def initialize(*args)
    super
    _smart_hash_init
  end

  # Alternative constructor.
  #
  #   person = SmartHash[]
  def self.[](*args)
    super.tap do |_|
      _.instance_eval do
        _smart_hash_init
      end
    end
  end

  # Declare attributes. By declaring the attributes you ensure that there's no
  # interference from existing methods.
  # 
  #   person = SmartHash[]
  #   person.declare(:size)
  #   person.size             # KeyError: key not found: :size
  #
  #   person.size = "XL"
  #   person.size             # => "XL"
  #
  # See also #undeclare.
  def declare(*attrs)
    raise ArgumentError, "No attrs specified" if attrs.empty?
    attrs.each do |attr|
      (v = attr).is_a?(klass = Symbol) or raise ArgumentError, "#{klass} expected, #{v.class} (#{v.inspect}) given"
      attr.to_s.match /\A#{ATTR_REGEXP}\z/ or raise ArgumentError, "Incorrect attribute name '#{attr}'"
      @declared_attrs << attr   # `Set` is returned.
    end
  end

  # Protect attributes from being assigned.
  #
  #   person = SmartHash[]
  #   person.name = "John"
  #   person.protect(:name)
  #
  #   person.name = "Bob"     # ArgumentError: Attribute 'name' is protected
  #
  # See also #unprotect.
  def protect(*attrs)
    raise ArgumentError, "No attrs specified" if attrs.empty?
    attrs.each do |attr|
      (v = attr).is_a?(klass = Symbol) or raise ArgumentError, "#{klass} expected, #{v.class} (#{v.inspect}) given"
      attr.to_s.match /\A#{ATTR_REGEXP}\z/ or raise ArgumentError, "Incorrect attribute name '#{attr}'"
      @protected_attrs << attr
    end
  end

  def undeclare(*attrs)
    raise ArgumentError, "No attrs specified" if attrs.empty?
    attrs.each do |attr|
      @declared_attrs.delete(attr)    # `Set` is returned.
    end
  end

  def unprotect(*attrs)
    raise ArgumentError, "No attrs specified" if attrs.empty?
    attrs.each do |attr|
      @protected_attrs.delete(attr)
    end
  end

  private

  # Make private copies of methods we need.
  [:fetch, :instance_eval].each do |method_name|
    my_method_name = "_smart_hash_#{method_name}".to_sym
    alias_method my_method_name, method_name
    private my_method_name
  end

  # Common post-initialize routine.
  def _smart_hash_init      #:nodoc:
    @declared_attrs = Set[]
    @strict = true

    # Protect only the bare minimum. Technically speaking, assigning ANYTHING that exists as a method is potentially dangerous
    # or confusing. So it's fairly pointless to try to protect everything. If the person wants to screw everything up on purpose,
    # he'll find a way to do it anyway.
    @protected_attrs = Set[:inspect, :to_s]

    # Suppress warnings.
    vrb, $VERBOSE = $VERBOSE, nil

    # Insert lookup routine for existing methods, such as <tt>size</tt>.
    methods.map(&:to_s).each do |method_name|
      # Install control routine on correct attribute access methods only.
      # NOTE: Check longer REs first.
      case method_name
      when /\A(#{ATTR_REGEXP})=\z/
        # Case "r.attr=".
        attr = $1.to_sym
        next if FORBIDDEN_ATTRS.include? attr
        _smart_hash_instance_eval <<-EOT
          def #{method_name}(value)
            raise ArgumentError, "Attribute '#{attr}' is protected" if @protected_attrs.include? :#{attr}
            self[:#{attr}] = value
          end
        EOT
      when /\A#{ATTR_REGEXP}\z/
        # Case "r.attr".
        next if FORBIDDEN_ATTRS.include? attr
        _smart_hash_instance_eval <<-EOT
          def #{method_name}(*args)
            if @declared_attrs.include?(:#{method_name}) or has_key?(:#{method_name})
              if @strict
                _smart_hash_fetch(:#{method_name})
              else
                self[:#{method_name}]
              end
            else
              super
            end
          end
        EOT
      end # case
    end # each

    # Restore warnings.
    $VERBOSE = vrb
  end

  def method_missing(method_name, *args)
    # NOTE: No need to check for forbidden attrs here, since they exist as methods by definition.

    case method_name
    when /\A(.+)=\z/
      # Case "r.attr=". Attribute assignment. Method name is pre-validated for us by Ruby.
      attr = $1.to_sym
      raise ArgumentError, "Attribute '#{attr}' is protected" if @protected_attrs.include? attr

      self[attr] = args[0]
    when /\A#{ATTR_REGEXP}\z/
      # Case "r.attr".
      if @strict
        _smart_hash_fetch(method_name)
      else
        self[method_name]
      end
    else
      super
    end
  end
end
