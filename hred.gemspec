lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ballad/version'

Gem::Specification.new do |spec|
  spec.name          = "ballad"
  spec.version       = Ballad::VERSION
  spec.authors       = ["ksss"]
  spec.email         = ["co000ri@gmail.com"]

  spec.summary       = %q{HTTP response edit by line}
  spec.description   = %q{HTTP response edit by line}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
end
