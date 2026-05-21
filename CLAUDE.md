# rmagick_tidy

## Commands

```bash
bundle exec rake          # RSpec + RuboCop (both must pass)
bundle exec rspec         # tests only
bundle exec rubocop       # lint only
```

## Workflow

- All changes go through pull requests — never commit directly to `main`.
- `main` is not branch-protected, but keep the PR-based flow for consistency.

## Releasing

To publish a new version to RubyGems, use the `release` skill
(`/release`) — see `.claude/skills/release/SKILL.md`.
