class SmartHash < Hash
  # Non-strict SmartHash
  #
  #   person = SmartHash::Loose[]
  #
  # is equivalent to:
  #
  #   person = SmartHash[]
  #   person.strict = false
  class Loose < ::SmartHash
    # See SmartHash#initialize.
    def initialize(*args)
      super
      @strict = false
    end

    # See SmartHash::[].
    def self.[](*args)
      super.tap do |_|
        _.strict = false
      end
    end
  end
end
