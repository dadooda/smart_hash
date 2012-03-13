require "set"

# Load our stuff.
# NOTE: Our includes are capable of being loaded in arbitrary order (for spec and stuff), hence the `< Hash` in each of them.
[
  "smart_hash/**/*.rb",
].each do |fmask|
  Dir[File.expand_path("../#{fmask}", __FILE__)].each do |fn|
    require fn
  end
end

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
    raise ArgumentError, "No attributes specified" if attrs.empty?
    attrs.each do |attr|
      [attr, Symbol].tap {|v, klass| v.is_a?(klass) or raise ArgumentError, "#{klass} expected, #{v.class} (#{v.inspect}) given"}
      attr.to_s.match /\A#{ATTR_REGEXP}\z/ or raise ArgumentError, "Incorrect attribute name: #{attr}"
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
    raise ArgumentError, "No attributes specified" if attrs.empty?
    attrs.each do |attr|
      [attr, Symbol].tap {|v, klass| v.is_a?(klass) or raise ArgumentError, "#{klass} expected, #{v.class} (#{v.inspect}) given"}
      attr.to_s.match /\A#{ATTR_REGEXP}\z/ or raise ArgumentError, "Incorrect attribute name: #{attr}"
      @protected_attrs << attr
    end
  end

  def undeclare(*attrs)
    raise ArgumentError, "No attributes specified" if attrs.empty?
    attrs.each do |attr|
      @declared_attrs.delete(attr)    # `Set` is returned.
    end
  end

  def unprotect(*attrs)
    raise ArgumentError, "No attributes specified" if attrs.empty?
    attrs.each do |attr|
      @protected_attrs.delete(attr)
    end
  end

  private

  # Make private copies of methods we need.
  [:fetch].each do |method_name|
    my_method_name = "_smart_hash_#{method_name}".to_sym
    alias_method my_method_name, method_name
    private my_method_name
  end

  # Common post-initialize routine.
  def _smart_hash_init      #:nodoc:
    # At early stages of construction via `[]` half-ready instances might be accessed.
    # Do determine such situations we need a flag.
    @is_initialized = true

    @declared_attrs = Set[]
    @strict = true

    # Protect only the bare minimum. Technically speaking, assigning ANYTHING that exists as a method is potentially dangerous
    # or confusing. So it's fairly pointless to try to protect everything. If the person wants to screw everything up on purpose,
    # he'll find a way to do it anyway.
    @protected_attrs = Set[:inspect, :to_s]

    # Extend own class with dynamic methods if needed.
    if not self.class < DynamicMethods
      method_names = methods.map(&:to_s)

      # Skip methods matching forbidden attrs.
      method_names -= FORBIDDEN_ATTRS.map(&:to_s) + FORBIDDEN_ATTRS.map {|_| "#{_}="}

      # Collect pieces of code.
      pcs = []

      method_names.each do |method_name|
        case method_name
        when /\A(#{ATTR_REGEXP})=\z/
          # Assignment.
          attr = $1.to_sym
          # NOTE: See `@is_initialized` checks -- our code must take control only when the object is fully initialized.
          pcs << %{
            def #{method_name}(value)
              if @is_initialized
                if @protected_attrs.include? :#{attr}
                  raise ArgumentError, "Attribute is protected: #{attr}"
                else
                  self[:#{attr}] = value
                end
              else
                super
              end
            end
          } # pcs <<
        when /\A(#{ATTR_REGEXP})\z/
          # Access.
          attr = $1.to_sym
          pcs << %{
            def #{method_name}(*args)
              if @is_initialized and (@declared_attrs.include?(:#{attr}) or has_key?(:#{attr}))
                if @strict
                  _smart_hash_fetch(:#{attr})
                else
                  self[:#{attr}]
                end
              else
                super
              end
            end
          } # pcs <<
        end # case
      end # method_names.each

      # Suppress warnings.
      vrb, $VERBOSE = $VERBOSE, nil

      # Create dynamic methods.
      DynamicMethods.class_eval pcs.join("\n")

      # Restore warnings.
      $VERBOSE = vrb

      # Include dynamic methods.
      self.class.class_eval "include DynamicMethods"
    end
  end

  def method_missing(method_name, *args)
    # NOTE: No need to check for forbidden attrs here, since they exist as methods by definition.

    case method_name
    when /\A(.+)=\z/
      # Assignment. Method name is pre-validated for us by Ruby.
      attr = $1.to_sym
      raise ArgumentError, "Attribute is protected: #{attr}" if @protected_attrs.include? attr
      self[attr] = args[0]
    when /\A(#{ATTR_REGEXP})\z/
      # Access.
      attr = $1.to_sym
      if @strict
        _smart_hash_fetch(attr)
      else
        self[attr]
      end
    else
      super
    end
  end
end
