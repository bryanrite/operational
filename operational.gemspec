# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'operational/version'

Gem::Specification.new do |spec|
  spec.name          = "operational"
  spec.version       = Operational::VERSION
  spec.authors       = ["Bryan Rite"]
  spec.email         = ["bryan@bryanrite.com"]

  spec.summary       = %q{Simplify your Ruby Application with Operations}
  spec.description   = %q{Help organize a complex business domain into a consistent and functional interface of immutable, stateless, and repeatable Operations}
  spec.homepage      = "https://github.com/bryanrite/operational"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
