# rmagick_tidy

`rmagick_tidy` は RMagick (`Magick::Image`) のメモリ管理を**スコープベース**で自動化する Ruby gem です。

RMagick が確保するメモリの実体は ImageMagick の C レイヤー側にあります。Ruby の GC は Ruby が確保したメモリしか把握しないため、ImageMagick 側の使用量を過小評価し、GC が適時に発火しません。Ruby ラッパが回収されるタイミングで C 側のメモリも最終的には解放されますが、それまではプロセスの RSS が膨らみ続けます。これを避けるため、`ensure + destroy!` を各所に手書きして即時解放しているプロジェクトが多いのが現状です。本 gem はその定型処理を 1 ブロックに集約します。

English: [README.md](README.md)

## インストール

```ruby
# Gemfile
gem "rmagick_tidy"
```

```ruby
require "rmagick_tidy"
```

`require` した時点で `Magick::Image` / `Magick::ImageList` のフックがインストールされます。

## 基本的な使い方

```ruby
RmagickTidy.scope do
  img = Magick::Image.read("input.jpg").first
  resized = img.resize(800, 600)
  resized.write("output.jpg")
end
# ブロックを抜けたタイミングで img, resized が destroy! 済み
```

### ブロックの戻り値は解放されない（keep）

呼び出し元に画像を返したい場合は、その画像をブロックの戻り値にします。

```ruby
result = RmagickTidy.scope do
  img = Magick::Image.read("input.jpg").first
  img.resize(800, 600)   # ← この戻り値だけは keep
end
# result は生きている。元の img は destroy! 済み

result.write("out.jpg")
result.destroy!
```

戻り値は `Magick::Image` 単体だけでなく、`Array<Image>`、`Hash` の値、`Magick::ImageList` 内の要素も再帰的に keep されます。

### ネスト

```ruby
RmagickTidy.scope do        # 外側
  outer = Magick::Image.read("a.jpg").first
  RmagickTidy.scope do      # 内側
    inner = outer.resize(100, 100)
    # inner はここで destroy!
  end
  # outer はまだ生きている
end
```

### 例外時も解放される

```ruby
RmagickTidy.scope do
  img = Magick::Image.read("x.jpg").first
  raise "boom"
end
# img は destroy! されてから例外が再送出される
```

### bang メソッドは二重登録されない

`resize!` などの bang メソッドは `self` を返すため、`equal?` で判定して再登録しません。

## Rails で使う

`require "rmagick_tidy"` を済ませると Railtie が `ActionController::Base` に `within_rmagick_tidy_scope` を mixin します。

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

`to_blob` は `String` を返すのでスコープの解放対象になりません。Image オブジェクトのみがクリーンアップされます。

## strict モード

開発・テスト環境で「スコープ外で作られた Image」を検知したいときに使います。

```ruby
RmagickTidy.configure do |c|
  c.strict_mode = :warn   # or :raise / :off (default)
end
```

- `:off` — 何もしない（本番デフォルト）
- `:warn` — `warn` で標準エラー出力に通知
- `:raise` — `RmagickTidy::OutOfScopeError` を発生

> **Configuration はスレッドセーフではありません。** `strict_mode`（および将来追加されるオプション）は **起動時に 1 回だけ**設定してください（例: Rails の initializer）。ワーカースレッドが `Magick::Image` を使い始めたあとに別スレッドから書き換える挙動は未定義です。

## 仕組み

- `Magick::Image` / `Magick::ImageList` に対し、`Module#prepend` で全ての public instance method（および `new`, `read`, `from_blob`, ...のクラスメソッド）をラップ
- **戻り値の型をチェック**して `Magick::Image` であれば現在のスコープに登録（ホワイトリストを持たないので RMagick のバージョン差異を吸収）
- 戻り値が `self` と `equal?` なら bang メソッドとみなして登録しない
- スコープスタックは `Thread.current` 配下なのでマルチスレッド環境でも安全
- 二重 `destroy!` は `destroyed?` 判定 + rescue で防止

## 対応バージョン

- Ruby 3.2 以上
- RMagick 2.x 〜 6.x（戻り値チェック方式のため幅広く動作）

## ライセンス

MIT
