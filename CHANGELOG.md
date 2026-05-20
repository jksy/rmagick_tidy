# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Required Ruby version raised to `>= 3.2.0` (matches the CI matrix).
- `Registry.destroy_safely` now only rescues `Magick::ImageMagickError` rather than all `StandardError`, so unrelated bugs surface instead of being swallowed.
- `Hook.define_wrapper` now uses `define_method` instead of string-based `module_eval` for readability.

### Added
- `LICENSE` file (MIT).
- Gem metadata (`source_code_uri`, `changelog_uri`, `bug_tracker_uri`, `rubygems_mfa_required`).
- RuboCop and SimpleCov for style and coverage; both run in CI.
- Codecov integration: CI emits `coverage/lcov.info` (via `simplecov-lcov`) and uploads it through `codecov/codecov-action@v4`. README displays the live coverage badge.
- Additional RSpec coverage for nested `Hash`/`Array` return values, `ImageList` iteration, missing `destroyed?`, `nil` / empty returns, and `destroy!` exception paths.
- README note about `Configuration` thread-safety expectations.

## [0.1.0]

### Added
- Initial release.
