# NOTE: I usually support `STANDALONE` mode in specs for Rails projects' components
#       to be able to test them without loading the environment. This project does not
#       depend on Rails *BUT* I still want a consistent RSpec file structure.
#       If this is confusing, feel free to propose something better. :)

# No Rails, we're always standalone... and free! :)
STANDALONE = 1

if STANDALONE
  # Provide root path object.
  module Standalone
    eval <<-EOT
      def self.root
        # This is an absolute path, it's perfectly safe to do a `+` and then `require`.
        Pathname("#{File.expand_path('../..', __FILE__)}")
      end
    EOT
  end

  # Load stuff.
  [
    "lib/**/*.rb",
  ].each do |fmask|
    Dir[Standalone.root + fmask].each do |fn|
      require fn
    end
  end
end # if STANDALONE

# Extend `Hash` with a non-forbidden `attr=` to test shadowing.
class ::Hash
  def something
    "something"
  end

  def something=(value)
    "something="
  end
end
