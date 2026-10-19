# nix-meltype

[Meltype](https://github.com/yksr-melt/Meltype) の fcitx5 アドオンと IBus エンジンを Nix で入れるための flake。

## これは何？

Meltype は、半角/全角キーで切り替えずに日本語と英語を混ぜて打てる日本語入力。
ローマ字で打つと、英単語は英字のまま、日本語はかな漢字に変換される。

```
kyouhagoogledekensaku  →  今日はgoogleで検索
```

upstream の Linux 版はインストールスクリプトで入れる。スクリプトは Ubuntu を前提にしていて、`/opt` とシステムの IBus / fcitx5 にファイルを置く。
この flake は、それを Nix のパッケージにしたもの。NixOS や、home-manager を使う他のディストリで、システムを汚さずに入れられる。
使い方は upstream の [USAGE.md](https://github.com/yksr-melt/Meltype/blob/main/docs/USAGE.md) を参照。

## インストール

導入手順はエージェント向けに [INSTALL.md](INSTALL.md) に書いてある。このリポジトリのメンテナンスは [AGENTS.md](AGENTS.md)。

下の文を Claude Code や Codex などのコーディングエージェントにコピペして渡す。

```text
https://raw.githubusercontent.com/aster-void/nix-meltype/main/INSTALL.md を読んで、その手順で Meltype をこのマシンに入れて。
- まずこのマシンの Nix 構成 (NixOS か、home-manager か、flake か、設定ファイルの場所) と、今動いている入力メソッド (fcitx5 / IBus、どこから起動しているか) を調べる
- Nix や home-manager が入っていなければ、入れる前に INSTALL.md の「Nix / home-manager が無い場合」に書かれた変更内容を私に説明して確認する
- 設定は既存の Nix 構成に追記する。選んだ方式の手順と INSTALL.md の「ハマりどころ」を全部確かめてから適用する
- fcitx5 と IBus のどちらで使うかは INSTALL.md の「2. fcitx5 と IBus のどちらで使うか決める」で決めて、私に確認する
- 既存の fcitx5 / IBus の設定を上書きする変更や、ディストリの IME を止める変更は、実行前に私に確認する
- 適用後にログインし直しが要るなら私に頼み、戻ってきたら INSTALL.md の「確認」を実行して結果を報告する
```

## ライセンス

このリポジトリの Nix 式と CI 設定は [Unlicense](LICENSE) でパブリックドメインに置いている。
upstream の作者 (yksr-melt) を含め誰でも、upstream への取り込み・別ライセンスでの再配布・自分の著作物としての再公開ができる。
ビルドされる Meltype 本体と Mozc は upstream のライセンス (GPL-3.0-or-later / BSD-3-Clause) に従う。
