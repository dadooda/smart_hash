require File.expand_path("../spec_helper", __FILE__)

describe SmartHash do
  before do
    # Get key error exception sample. Should be `KeyError` for 1.9, `IndexError` for 1.8.
    @key_error = {}.fetch(:kk) rescue $!.class
  end

  it "should generally work" do
    r = described_class.new
    r.should == {}

    r = described_class[]
    r.should == {}

    r = described_class[:name => "John"]
    r.should == {:name => "John"}

    r = described_class[]
    r[:name].should == nil
    lambda {r.name}.should raise_error @key_error
    r.name = "John"
    r.should == {:name => "John"}

    r = described_class[]
    r[:young?] = true           # This is allowed, we're `Hash`.
    lambda {r.young?}.should raise_error NoMethodError   # Because `young?` is not a valid attribute name.
    r[:go!] = true
    lambda {r.go!}.should raise_error NoMethodError   # Same as above.

    # Existing method shadowed by an attribute.
    r = described_class[:name => "John"]
    r.size.should == 1
    (r.size = "XL").should == "XL"
    r.size.should == "XL"

    # Existing `attr=` method shadowed by an attribute.
    # NOTE: `:something` and `:something=` are methods we've added in `Hash`, see spec helper.
    r = described_class[]
    r.method(:something=).should be_a Method
    r.something = 99
    r.something.should == 99
  end # it "should generally work"

  it "should allow to redefine `fetch`" do
    r = described_class[]
    r.fetch = 99
    r.fetch.should == 99
    r.name = "John"
    r.name.should == "John"
    r.should == {:fetch => 99, :name => "John"}
  end

  describe "ATTR_REGEXP" do
    before :each do
      re = described_class.const_get(:ATTR_REGEXP)
      @access_regexp = /\A#{re}\z/
      @assign_regexp = /\A#{re}=\z/
    end

    it "should generally work" do
      # Errors first, OKs second.
      @access_regexp.tap do |_|
        "".should_not match _
        "911".should_not match _
        "911abc".should_not match _
        "young?".should_not match _
        "go!".should_not match _
      end

      @access_regexp.tap do |_|
        "good_attr".should match _
        "_".should match _
        "__abc99__".should match _
      end

      @assign_regexp.tap do |_|
        "good_attr=".should match _
      end
    end
  end

  describe "attribute declaration" do
    it "should generally work" do
      r = described_class[:name => "John"]
      r.declare(:size)
      r.declared_attrs.should include :size
      lambda {r.size}.should raise_error @key_error
      r.undeclare(:size)
      r.size.should == 1

      # Direct modification.
      r = described_class[:name => "John"]
      r.declared_attrs << :size
      lambda {r.size}.should raise_error @key_error
      r.declared_attrs.clear
      r.size.should == 1
    end

    describe "#declare" do
      it "should not accept empty attrs list" do
        r = described_class[]
        lambda {r.declare}.should raise_error ArgumentError
      end

      it "should accept multiple attrs" do
        r = described_class[]
        r.declare(:count, :size)
        r.declared_attrs.should include :count
        r.declared_attrs.should include :size
      end

      it "should accept `Symbol` only" do
        r = described_class[]
        lambda {r.declare(1)}.should raise_error ArgumentError
        lambda {r.declare("some_attr")}.should raise_error ArgumentError
        lambda {r.declare(:some_attr)}.should_not raise_error
      end

      it "should validate attribute name" do
        r = described_class[]
        lambda {r.declare(:good_attr)}.should_not raise_error
        lambda {r.declare(:bad_attr!)}.should raise_error ArgumentError
        lambda {r.declare(:bad_attr?)}.should raise_error ArgumentError
      end
    end # describe "#declare"

    describe "#undeclare" do
      it "should not accept empty attrs list" do
        r = described_class[]
        lambda {r.undeclare}.should raise_error ArgumentError
      end

      it "should accept multiple attrs" do
        r = described_class[:name => "John"]
        r.declare(:count, :size)
        lambda {r.count}.should raise_error @key_error
        lambda {r.size}.should raise_error @key_error
        r.undeclare(:count, :size)
        r.count.should == 1
        r.size.should == 1
      end

      it "should generally work" do
        r = described_class[:name => "John"]
        r.declare(:size)
        lambda {r.size}.should raise_error @key_error
        r.undeclare(:size)
        r.size.should == 1
      end

      it "should not be strict" do
        r = described_class[]
        lambda {r.undeclare("young?")}.should_not raise_error
        lambda {r.undeclare(5)}.should_not raise_error
        lambda {r.undeclare([])}.should_not raise_error
      end
    end
  end # describe "attribute declaration"

  describe "attribute protection" do
    it "should generally work" do
      # General.
      r = described_class[]
      r.protect(:name)
      lambda {r.name = "John"}.should raise_error ArgumentError

      # Direct modification.
      r = described_class[]
      r.protected_attrs << :name
      lambda {r.name = "John"}.should raise_error ArgumentError
      r.protected_attrs.delete :name
      lambda {r.name = "John"}.should_not raise_error ArgumentError

      # Existing method.
      r = described_class[:name => "John"]
      r.protect(:size)
      lambda {r.size = "XL"}.should raise_error ArgumentError
      r.size.should == 1

      # Protect/unprotect.
      r = described_class[]
      r.protect(:name)
      lambda {r.name = "John"}.should raise_error ArgumentError
      r.unprotect(:name)
      r.name = "Johnny"
      r.name.should == "Johnny"

      # Existing "attr=".
      r = described_class[]
      r.something.should == "something"
      r.protect(:something)
      lambda {r.something = "other"}.should raise_error ArgumentError
      r.unprotect(:something)
      r.something = "other"
      r.something.should == "other"
      r.delete(:something)
      r.something.should == "something"
    end

    it "should protect sensitive attrs by default" do
      r = described_class[]
      lambda {r.inspect = 99}.should raise_error ArgumentError
      lambda {r.to_s = 99}.should raise_error ArgumentError
    end

    it "should allow to unprotect sensitive attrs if needed" do
      r = described_class[]
      r.unprotect(:inspect)
      r.inspect = "top_secret"
      r.inspect.should == "top_secret"

      r = described_class[]
      r.unprotect(:to_s)
      r.to_s = "top_secret"
      "#{r}".should == "top_secret"
    end

    describe "#protect" do
      it "should not accept empty attrs list" do
        r = described_class[]
        lambda {r.protect}.should raise_error ArgumentError
      end

      it "should accept multiple attrs" do
        r = described_class[]
        r.protect(:count, :size)
        r.protected_attrs.should include :count
        r.protected_attrs.should include :size
      end
    end # describe "#protect"

    describe "#unprotect" do
      it "should not accept empty attrs list" do
        r = described_class[]
        lambda {r.unprotect}.should raise_error ArgumentError
      end

      it "should accept multiple attrs" do
        r = described_class[]
        r.protect(:count, :size)
        r.protected_attrs.should include :count
        r.protected_attrs.should include :size
        r.unprotect(:count, :size)
        r.protected_attrs.should_not include :count
        r.protected_attrs.should_not include :size
      end
    end
  end # describe "attribute declaration"

  describe "defaults" do
    it "should generally work" do
      # Default, scalar.
      r = described_class[]
      r.default = 99
      r.should == {}              # Because `default` is a forbidden (non-attribute) name, but built-in method exists and it responds.
      r[:anything].should == 99   # Because this is the default `Hash` behavior.
      lambda {r.anything}.should raise_error @key_error   # Because attribute access is more strict and default doesn't affect it.

      # Default, proc.
      r = described_class[]
      r.default_proc = lambda {|h, k| "<#{k}>"}
      r.should == {}
      r[:anything].should == "<anything>"
      r[:other].should == "<other>"
      lambda {r.anything}.should raise_error @key_error

      # Loose mode.
      r = described_class[]
      r.strict = false
      r.anything.should == nil

      # Loose mode with default.
      r = described_class[]
      r.strict = false
      r.default = 99
      r[:anything].should == 99
      r.anything.should == 99
    end
  end # describe "defaults"
end # describe SmartHash do

describe SmartHash::Loose do
  it "should generally work" do
    r = described_class[]
    r.anything.should == nil

    r = described_class[]
    r.default = 99
    r[:anything].should == 99
    r.anything.should == 99
  end
end
