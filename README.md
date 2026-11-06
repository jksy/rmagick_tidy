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

## Rack middleware

For Sinatra, Hanami, or any other Rack app, `RmagickTidy::Middleware` runs each request inside a scope. It relies only on the Rack interface; `rack` is not a dependency of this gem.

```ruby
# config.ru
use RmagickTidy::Middleware
```

The scope stays open until the server calls `close` on the response body, so a streaming body (or an `Enumerator`) that creates or uses images while it is iterated is still covered. When the app returns an `Array` body, the scope ends as soon as the app returns.

- The scope relies on the server calling `body.close`, as the Rack spec requires. If a server never closes the body, the images of that request are not released.
- Between the app returning and the body being closed, images created on the same thread (for example by middleware further out) are registered with this scope too, and are released when the body is closed.

## Background jobs

### ActiveJob

`include RmagickTidy::JobExtension` registers an `around_perform` callback that runs `perform` inside a scope. Unlike `RmagickTidy.scope`, nothing is kept: an image returned from `perform` (for example by a trailing `img.write(path)`, which returns `img`) is released too, since a job's return value is normally unused. `perform_now` still returns `perform`'s value.

```ruby
class ThumbnailJob < ApplicationJob
  include RmagickTidy::JobExtension

  def perform(path)
    img = Magick::Image.read(path).first
    img.resize(200, 200).write(path.sub(/\.jpg\z/, "_thumb.jpg"))
  end
end
```

### Sidekiq

For plain Sidekiq jobs, add the server middleware. Every image created by the job is released when it finishes.

```ruby
Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add RmagickTidy::Sidekiq::ServerMiddleware
  end
end
```

Neither ActiveJob nor Sidekiq is a dependency of this gem; both helpers are loaded by `require "rmagick_tidy"`.

## Strict mode

Use strict mode in development or test environments to catch images created outside of a scope.

```ruby
RmagickTidy.configure do |c|
  c.strict_mode = :warn   # or :raise / :off (default)
end
```

- `:off` — do nothing (the production default)
- `:warn` — print a warning to stderr
- `:raise` — raise `RmagickTidy::OutOfScopeError`

> **Configuration is not thread-safe.** Set `strict_mode` (and any future
> options) **once at boot** — for example from a Rails initializer — before any
> worker thread starts using `Magick::Image`. Reading and writing the value
> from multiple threads concurrently is undefined.

## How it works

- `Magick::Image` and `Magick::ImageList` are hooked with `Module#prepend`, wrapping every public instance method as well as class methods such as `new`, `read`, and `from_blob`.
- Each wrapped method **inspects its return value**: if it is a `Magick::Image`, the image is registered with the current scope. Because the gem keeps no method whitelist, it works across a wide range of RMagick versions.
- If the return value is `equal?` to `self`, it is treated as a bang method and not registered. Likewise, an image is registered only the first time it is seen (tracked by identity in an `ObjectSpace::WeakMap`): images handed back from a list, such as by `ImageList#[]`, `#first`, `#pop`, `#delete`, or the shallow copy from `ImageList#dup`, are not registered again, so working with a list created outside the scope does not destroy its images.
- `dup` / `clone` are wrapped too: `Magick::Image#dup` and `#clone` allocate a new image, which is tracked like any other.
- The scope stack lives in `Thread.current`, so it is safe to use under multi-threaded servers such as Puma.
- Calling `destroy!` twice is guarded against with a `destroyed?` check and a defensive `rescue`.

## Compatibility

- Ruby 3.3 or newer
- RMagick 2.x through 6.x (the return-value approach keeps the gem broadly compatible)

## License

MIT
