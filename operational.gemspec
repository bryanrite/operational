lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'operational/version'

Gem::Specification.new do |spec|
  spec.name          = "operational"
  spec.version       = Operational::VERSION
  spec.authors       = ["Bryan Rite"]
  spec.email         = ["bryan@bryanrite.com"]

  spec.summary       = %q{Lightweight, railway-oriented operation and form objects for business logic}
  spec.description   = %q{Operational wraps your business logic into operations — small classes with a railway of steps that succeed or fail. Pair them with form objects and contracts to decouple your UI and APIs from your models.}
  spec.homepage      = "https://github.com/bryanrite/operational"
  spec.license       = "MIT"

  spec.metadata = {
    "changelog_uri"     => "https://github.com/bryanrite/operational/blob/master/CHANGELOG.md",
    "source_code_uri"   => "https://github.com/bryanrite/operational",
    "documentation_uri" => "https://github.com/bryanrite/operational#readme",
    "bug_tracker_uri"   => "https://github.com/bryanrite/operational/issues"
  }

  spec.files         = Dir["lib/**/*", "LICENSE", "README.md", "AI_README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = Gem::Requirement.new(">= 3.0")

  spec.add_dependency("activemodel", ">= 7.0.0")

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
