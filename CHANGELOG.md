# Changelog

Release notes for versions after 0.1.0 are published on
[GitHub Releases](https://github.com/jksy/rmagick_tidy/releases), generated
from merged pull requests. This file is kept for the history below.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-21

### Added
- Initial release: `RmagickTidy.scope` block that tracks every `Magick::Image` / `Magick::ImageList` created inside it and calls `destroy!` on them when the block exits.
- `LICENSE` file (MIT).
- Gem metadata (`source_code_uri`, `changelog_uri`, `bug_tracker_uri`, `rubygems_mfa_required`).
- RuboCop and SimpleCov for style and coverage; both run in CI.
- Codecov integration: CI emits `coverage/lcov.info` (via `simplecov-lcov`) and uploads it through `codecov/codecov-action@v4`. README displays the live coverage badge.
- RSpec coverage for nested `Hash`/`Array` return values, `ImageList` iteration, missing `destroyed?`, `nil` / empty returns, and `destroy!` exception paths.
- README note about `Configuration` thread-safety expectations.
