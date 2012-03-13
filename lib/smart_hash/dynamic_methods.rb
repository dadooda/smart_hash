require File.expand_path("../../smart_hash", __FILE__)

class SmartHash < Hash
  # This module will get dynamically extended with methods which exist in `Hash`.
  module DynamicMethods
  end
end
