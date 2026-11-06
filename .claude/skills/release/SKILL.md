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

## 3. Check PR labels

Release notes are generated from merged PRs and grouped by their labels
(see `RELEASING.md` and `.github/release.yml`). `CHANGELOG.md` is no longer
updated. Review the PRs merged since the last tag and make sure each
user-facing change has a type label (`breaking change` / `enhancement` /
`bug` / `security`); the label also tells you which semver part to bump.

```bash
gh pr list --state merged --search "merged:>$(git log -1 --format=%cs "$(git describe --tags --abbrev=0)")" --json number,title,labels
```

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
git add lib/rmagick_tidy/version.rb
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

Pushing the tag triggers the `github-release` workflow, which creates the
GitHub Release with generated notes.

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

```bash
gh release view vX.Y.Z
```

Confirm the GitHub Release exists and its notes are grouped as expected.
If the workflow failed, create it by hand with
`gh release create vX.Y.Z --generate-notes --verify-tag`.
