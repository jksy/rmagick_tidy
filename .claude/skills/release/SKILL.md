---
name: release
description: Publish a new version of the rmagick_tidy gem to RubyGems. Use when the user asks to release, publish, cut a version, or ship a new gem version.
disable-model-invocation: true
---

# Releasing rmagick_tidy to RubyGems

Follow these steps in order. Confirm the target version number with the user before starting.

## 1. Start from an up-to-date main

```bash
git checkout main && git pull origin main
```

## 2. Bump the version

Edit `lib/rmagick_tidy/version.rb` and set `VERSION` to the new value
(follow [Semantic Versioning](https://semver.org/)).

## 3. Update the CHANGELOG

In `CHANGELOG.md`, move the contents of `[Unreleased]` into a new
`[X.Y.Z] - YYYY-MM-DD` section (use today's date). Leave an empty
`[Unreleased]` section at the top for future changes.

## 4. Verify locally

```bash
bundle exec rake          # runs RSpec + RuboCop, both must pass
gem build rmagick_tidy.gemspec   # must succeed with no warnings
rm -f rmagick_tidy-*.gem  # discard the local build artifact
```

## 5. Open a release PR

Do **not** commit release-prep changes directly to `main`. Put them on a
branch and open a PR (matches this repo's PR-based workflow):

```bash
git checkout -b chore/release-X.Y.Z
git add lib/rmagick_tidy/version.rb CHANGELOG.md
git commit -m "Prepare X.Y.Z release"
git push -u origin chore/release-X.Y.Z
gh pr create --title "Prepare X.Y.Z release" --body "..."
```

## 6. Merge after CI passes

Wait for CI to go green, then merge the PR.

## 7. Release from the merged main

```bash
git checkout main && git pull origin main   # IMPORTANT: sync to the merge commit first
gem signin                                  # first time / when logged out; MFA OTP required
bundle exec rake release                    # tags vX.Y.Z, pushes tag, runs gem push
```

`rake release` requires a clean working tree. Running it from the
updated main makes the `vX.Y.Z` tag point at the merge commit.

The `gem push` step prompts for an MFA OTP (the gemspec sets
`rubygems_mfa_required`), so a human must run this step interactively —
an agent cannot complete it.

## 8. Verify

```bash
curl -s https://rubygems.org/api/v1/gems/rmagick_tidy.json
```

Confirm the reported `version` matches the new release.
