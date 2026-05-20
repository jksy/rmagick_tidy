# rmagick_tidy

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
- If the return value is `equal?` to `self`, it is treated as a bang method and not registered.
- The scope stack lives in `Thread.current`, so it is safe to use under multi-threaded servers such as Puma.
- Calling `destroy!` twice is guarded against with a `destroyed?` check and a defensive `rescue`.

## Compatibility

- Ruby 3.2 or newer
- RMagick 2.x through 6.x (the return-value approach keeps the gem broadly compatible)

## License

MIT
