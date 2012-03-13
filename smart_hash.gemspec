require File.expand_path("../lib/smart_hash/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "smart_hash"
  s.version = SmartHash::VERSION
  s.authors = ["Alex Fortuna"]
  s.email = ["alex.r@askit.org"]
  s.homepage = "http://github.com/dadooda/smart_hash"

  # Copy these from class's description, adjust markup.
  s.summary = %q{A smarter alternative to OpenStruct}
  s.description = %q{A smarter alternative to OpenStruct}
  # end of s.description=

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map {|f| File.basename(f)}
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
  s.add_development_dependency "yard"
end
