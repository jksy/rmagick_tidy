# rmagick_tidy

[![CI](https://github.com/jksy/rmagick_tidy/actions/workflows/ci.yml/badge.svg)](https://github.com/jksy/rmagick_tidy/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/jksy/rmagick_tidy/branch/main/graph/badge.svg)](https://codecov.io/gh/jksy/rmagick_tidy)

`rmagick_tidy` is a Ruby gem that automates **scope-based memory management** for RMagick (`Magick::Image`).

The bulk of the memory an `Magick::Image` represents is allocated by ImageMagick in C, outside Ruby's heap. Ruby's GC only accounts for memory it allocated itself, so it underestimates the real footprint and fires far less often than the actual memory pressure warrants. The C-side memory is eventually freed when the Ruby wrapper is collected, but until then the process's RSS keeps climbing. To avoid that, many projects scatter `ensure` / `destroy!` pairs through their code to release the memory immediately. This gem replaces that boilerplate with a single block.

日本語版: [README.ja.md](README.ja.md)

## Installation

```ruby
# Gemfile
gem "rmagick_tidy"
```

```ruby
require "rmagick_tidy"
```

Hooks for `Magick::Image` and `Magick::ImageList` are installed when the gem is required.

## Basic usage

```ruby
RmagickTidy.scope do
  img = Magick::Image.read("input.jpg").first
  resized = img.resize(800, 600)
  resized.write("output.jpg")
end
# Both img and resized have been released by the time the block exits.
```

### The block return value is preserved (keep set)

When you need to return an image to the caller, make it the block's return value.

```ruby
result = RmagickTidy.scope do
  img = Magick::Image.read("input.jpg").first
  img.resize(800, 600)   # returned from the block, so it is kept
end
# result is still alive; the original img has been released.

result.write("out.jpg")
result.destroy!
```

The keep set walks the return value recursively: a single `Magick::Image`, an `Array<Image>`, the values of a `Hash`, and the elements of a `Magick::ImageList` are all preserved.

### Nesting

```ruby
RmagickTidy.scope do        # outer scope
  outer = Magick::Image.read("a.jpg").first
  RmagickTidy.scope do      # inner scope
    inner = outer.resize(100, 100)
    # inner is released here.
  end
  # outer is still alive.
end
```

### Cleanup runs on exceptions too

```ruby
RmagickTidy.scope do
  img = Magick::Image.read("x.jpg").first
  raise "boom"
end
# img is released before the exception propagates.
```

### Bang methods are not registered twice

Bang methods such as `resize!` return `self`. `rmagick_tidy` detects this with an `equal?` check and skips re-registration, so the same image is never released twice.

## Rails integration

After `require "rmagick_tidy"`, a Railtie mixes `within_rmagick_tidy_scope` into `ActionController::Base`.

```ruby
class ImagesController < ApplicationController
  around_action :within_rmagick_tidy_scope

  def show
    img = Magick::Image.read(@source).first
    @blob = img.resize(800, 600).to_blob { |info| info.format = "JPEG" }
    send_data @blob, type: "image/jpeg"
  end
end
```

`to_blob` returns a `String`, so it is never treated as a cleanup target — only the image objects are released.

## Other frameworks and job queues

The gem itself only hooks into Rails controllers. Anywhere else, wrap the unit of work in `RmagickTidy.scope` yourself. It only takes a few lines, and keeping them in your app means you control them when those libraries change.

### Rack middleware (Sinatra, Hanami, plain Rack, ...)

```ruby
class RmagickTidyMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    RmagickTidy.scope { @app.call(env) }
  end
end

use RmagickTidyMiddleware
```

The scope ends when the app returns, before the server sends the body. That is fine for bodies whose content is already built (an `Array` of strings, a Rails or Sinatra response). If a streaming body or an `Enumerator` creates or uses images while it is being sent, do that image work inside the body, in its own `RmagickTidy.scope`; images created by the app and used later by the body are already released by then.

### ActiveJob

```ruby
class ApplicationJob < ActiveJob::Base
  around_perform do |_job, block|
    RmagickTidy.scope do
      block.call
      nil
    end
  end
end
```

The `nil` stops the scope from keeping what `perform` returns. A `perform` that ends with `img.write(path)` returns `img` itself, which would otherwise stay alive until GC.

### Sidekiq

```ruby
class RmagickTidySidekiqMiddleware
  def call(_job, _payload, _queue)
    RmagickTidy.scope do
      yield
      nil
    end
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add RmagickTidySidekiqMiddleware
  end
end
```

For ActiveJob jobs running on Sidekiq, either the `around_perform` above or this middleware is enough; using both just nests the scopes.

## Strict mode

Use strict mode in development or test environments to catch images created outside of a scope.

```ruby
RmagickTidy.configure do |c|
  c.strict_mode = :warn   # or :raise / :off (default)
end
```

- `:off` — do nothing (the production default)
- `:warn` — print a warning to stderr (or to `logger`, if set)
- `:raise` — raise `RmagickTidy::OutOfScopeError`

To send `:warn` messages to a logger instead of stderr, set `logger` to any
object that responds to `warn(message)` (e.g. `Rails.logger`). When `logger`
is `nil` (the default), the warning falls back to `Kernel#warn`. The Railtie
does not set it for you, so Rails apps opt in from an initializer:

```ruby
RmagickTidy.configure do |c|
  c.strict_mode = :warn
  c.logger = Rails.logger
end
```

> **Configuration is not thread-safe.** Set `strict_mode` and `logger` (and
> any future options) **once at boot** — for example from a Rails initializer —
> before any worker thread starts using `Magick::Image`. Reading and writing the value
> from multiple threads concurrently is undefined.

## Memory benchmark

[`benchmark/memory.rb`](benchmark/memory.rb) reads and resizes a generated image in a loop, once without `RmagickTidy.scope` and once with it, and prints the process RSS as it goes:

```bash
bundle exec ruby benchmark/memory.rb
ITERATIONS=100 SIZE=4000 bundle exec ruby benchmark/memory.rb
```

With the defaults (50 iterations, 3000x3000 source; Ruby 3.4, RMagick 7.2, ImageMagick 7.1 Q16-HDRI on Linux), RSS climbed to about 340 MB without the scope and stayed at about 57 MB with it. Exact numbers depend on your platform and ImageMagick build.

## How it works

- `Magick::Image` and `Magick::ImageList` are hooked with `Module#prepend`, wrapping every public instance method as well as class methods such as `new`, `read`, and `from_blob`.
- Each wrapped method **inspects its return value**: if it is a `Magick::Image`, the image is registered with the current scope. Because the gem keeps no method whitelist, it works across a wide range of RMagick versions.
- If the return value is `equal?` to `self`, it is treated as a bang method and not registered. Likewise, an image is registered only the first time it is seen (tracked by identity in an `ObjectSpace::WeakMap`): images handed back from a list, such as by `ImageList#[]`, `#first`, `#pop`, `#delete`, or the shallow copy from `ImageList#dup`, are not registered again, so working with a list created outside the scope does not destroy its images.
- `dup` / `clone` are wrapped too: `Magick::Image#dup` and `#clone` allocate a new image, which is tracked like any other.
- The scope stack lives in `Thread.current`, so it is safe to use under multi-threaded servers such as Puma.
- Calling `destroy!` twice is guarded against with a `destroyed?` check and a defensive `rescue`.

## Compatibility

- Ruby 3.3 or newer
- RMagick 5.x through 7.x (CI tests against 6.x and 7.x)

## License

MIT
