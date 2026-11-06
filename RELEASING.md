# リリース手順

RubyGems への公開手順は `.claude/skills/release/SKILL.md`（`/release` スキル）を参照。
`bundle exec rake release` でタグ `vX.Y.Z` を push すると、`github-release` ワークフローが
GitHub Release を作成し、マージ済み PR からリリースノートを自動生成する。

`CHANGELOG.md` は 0.1.0 までの履歴として残しているだけで、更新は不要。

## PR のラベル

リリースノートは PR のラベルで分類される（`.github/release.yml`、上から最初に一致した分類に入る）。
`lib/` の変更が機能追加か修正かはファイルからは判別できないので、**PR を作るときに種別ラベルを 1 つ手で付ける**。

| 分類 | ラベル | 付け方 |
|---|---|---|
| Breaking Changes | `breaking change` | 手で付ける（major） |
| New Features | `enhancement` | 手で付ける（minor） |
| Bug Fixes | `bug` | 手で付ける（patch） |
| Security | `security` | 手で付ける |
| Documentation | `documentation` | labeler（`.claude/` 以外の `**/*.md`） |
| Dependencies | `dependencies` | Dependabot |
| CI | `github_actions` | labeler（`.github/**`）、Dependabot（GitHub Actions の更新） |

ドキュメントだけ・CI だけの PR は labeler が付けるラベルで足りる。
どのラベルにも当たらない PR は "Other Changes" に入る。

リリース前に、前回のタグ以降にマージされた PR のラベルを見直しておくとよい:

```bash
gh pr list --state merged --search "merged:>$(git log -1 --format=%cs "$(git describe --tags --abbrev=0)")" --json number,title,labels
```
