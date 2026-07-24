require_relative "lib/rmagick_tidy/version"

Gem::Specification.new do |spec|
  spec.name          = "rmagick_tidy"
  spec.version       = RmagickTidy::VERSION
  spec.authors       = ["Junichiro Kasuya"]
  spec.email         = ["junichiro.kasuya@gmail.com"]

  spec.summary       = "Automatic scope-based memory management for RMagick (Magick::Image)."
  spec.description   = "rmagick_tidy provides a scope block that automatically tracks every " \
                       "Magick::Image / Magick::ImageList produced inside it and calls " \
                       "destroy! on them when the block exits, so callers no longer need " \
                       "to litter their code with ensure + destroy! pairs."
  spec.homepage      = "https://github.com/jksy/rmagick_tidy"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/jksy/rmagick_tidy/tree/main",
    "changelog_uri" => "https://github.com/jksy/rmagick_tidy/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/jksy/rmagick_tidy/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files         = Dir["lib/**/*.rb", "README.md", "README.ja.md", "CHANGELOG.md", "LICENSE*"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rmagick", ">= 5.0", "< 8"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "simplecov", "~> 1.0"
  spec.add_development_dependency "simplecov-lcov", "~> 0.8"
end
