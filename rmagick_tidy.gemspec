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
  spec.required_ruby_version = ">= 2.7.0"

  spec.files         = Dir["lib/**/*.rb", "README.md", "LICENSE*"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rmagick", ">= 2.0"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "bundler", ">= 1.17"
  spec.add_development_dependency "rake", ">= 12.0"
end
