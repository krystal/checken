require_relative './lib/checken/version'
Gem::Specification.new do |s|
  s.name          = "checken"
  s.description   = %q{An authorization framework for Ruby & Rails applications.}
  s.summary       = %q{This gem provides a friendly DSL for managing and enforcing permissions.}
  s.homepage      = "https://github.com/krystal/checken"
  s.version       = Checken::VERSION
  s.files         = Dir.glob("VERSION") + Dir.glob("{lib}/**/*")
  s.require_paths = ["lib"]
  s.authors       = ["Adam Cooke"]
  s.email         = ["adam@krystal.io"]
  s.licenses      = ['MIT']
  s.metadata["rubygems_mfa_required"] = "false" # Enabling MFA means we cannot auto publish via the CI
  s.metadata["changelog_uri"] = "https://github.com/krystal/checken/CHANGELOG.md"
end
