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

### 手で入れる

NixOS では、home-manager で `i18n.inputMethod` を設定していなければ、home-manager があっても NixOS 側に書く
(書き方は下の NixOS の段落)。non-NixOS では home-manager の module `homeModules.default` を読み込んで、
`programs.meltype` を書く。この module は `i18n.inputMethod` の `enable` / `type` を設定しないので、fcitx5 で使うときは自分で書く。デスクトップごとの workaround (GNOME の IBus unit の mask、
Plasma で KWin に fcitx5 を起動させる設定) と、環境変数の `environment.d` への書き出しは module がする。

```nix
# flake.nix
inputs.nix-meltype = {
  url = "github:aster-void/nix-meltype";
  inputs.nixpkgs.follows = "nixpkgs";
};
# homeManagerConfiguration の modules (NixOS の home-manager なら home-manager.sharedModules) に
# inputs.nix-meltype.homeModules.default を足す
```

```nix
# fcitx5
i18n.inputMethod = {
  enable = true;
  type = "fcitx5";
  fcitx5.waylandFrontend = true;
};
programs.meltype = {
  enable = true;
  framework.fcitx5.desktopWorkaround = "gnome"; # "gnome" | "plasma" | "none"
};

# IBus (non-NixOS の GNOME で、ディストリの ibus-daemon に足す)
programs.meltype = {
  enable = true;
  framework.gnomeIbus = { };
};
```

NixOS では、`i18n.inputMethod` の `fcitx5.addons` か `ibus.engines` に
`packages.<system>.fcitx5-meltype` / `ibus-meltype` を入れる。

適用したら、ディストリの IME の autostart を止めて、入力メソッドに `meltype` を追加し、ログインし直す
(手順は INSTALL.md の「4. 既存の IME を止める」と「5. 設定を適用して Meltype を入力メソッドに追加する」)。

## ライセンス

このリポジトリの Nix 式と CI 設定は [Unlicense](LICENSE) でパブリックドメインに置いている。
upstream の作者 (yksr-melt) を含め誰でも、upstream への取り込み・別ライセンスでの再配布・自分の著作物としての再公開ができる。
ビルドされる Meltype 本体と Mozc は upstream のライセンス (GPL-3.0-or-later / BSD-3-Clause) に従う。
