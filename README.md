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

設定は NixOS と home-manager のどちらか一方にだけ書く。NixOS の `i18n.inputMethod` と home-manager の `i18n.inputMethod` は、
名前と項目が似ているだけの別の module で、両方で有効になると入力メソッドが2つ並んで動く。

| 環境 | 書く場所 |
|---|---|
| NixOS | NixOS の設定 (`configuration.nix` など)。home-manager を使っていてもこちら |
| NixOS で、home-manager の `i18n.inputMethod` をすでに使っている | home-manager の設定 |
| NixOS 以外のディストリ | home-manager の設定 |

NixOS で home-manager を使っていても NixOS 側に書くのは、NixOS の GNOME が NixOS の `i18n.inputMethod` で IBus を既定で有効にするから。
home-manager に fcitx5 を書くと、その IBus と並んで動く。

どちらの場合も、flake に input を足す。

```nix
# flake.nix
inputs.nix-meltype = {
  url = "github:aster-void/nix-meltype";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

#### NixOS の設定に書く

この flake の overlay `overlays.default` を `nixpkgs.overlays` に足し、NixOS の `i18n.inputMethod` にパッケージを入れる。
overlay は、システムの fcitx5 に対してアドオンをビルドする。`programs.meltype` は使わない (home-manager 専用)。
`inputs` は `specialArgs = { inherit inputs; };` で module に渡しておく。

```nix
# configuration.nix など (NixOS module)
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.nix-meltype.overlays.default ];
  i18n.inputMethod = {
    enable = true;
    # fcitx5
    type = "fcitx5";
    fcitx5.addons = [ pkgs.fcitx5-meltype ];
    fcitx5.waylandFrontend = true;
    # IBus
    # type = "ibus";
    # ibus.engines = [ pkgs.ibus-meltype ];
  };
}
```

#### home-manager の設定に書く

この flake の home-manager module `homeModules.default` を読み込んで、`programs.meltype` を書く。
standalone の home-manager では `homeManagerConfiguration` の `modules` に、NixOS の module として使う home-manager では
`home-manager.sharedModules` に `inputs.nix-meltype.homeModules.default` を足す。

`programs.meltype` は、home-manager の `pkgs` の fcitx5 に対してビルドしたアドオンの追加と、デスクトップごとの workaround (GNOME の IBus unit の mask、Plasma で KWin に fcitx5 を起動させる設定)、
環境変数の `environment.d` への書き出しをする。home-manager の `i18n.inputMethod` の `enable` / `type` は設定しないので、fcitx5 で使うときは自分で書く。

```nix
# home.nix など (home-manager module)

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

# IBus (NixOS 以外の GNOME で、ディストリの ibus-daemon に足す)
programs.meltype = {
  enable = true;
  framework.gnomeIbus = { };
};
```

NixOS 以外で、GNOME 以外のデスクトップの IBus に Meltype を足す方法は今のところサポートしていない。その環境では fcitx5 で使う。

#### 適用したあと

適用したら、ディストリの IME の autostart を止めて、入力メソッドに `meltype` を追加し、ログインし直す
(手順は INSTALL.md の「4. 既存の IME を止める」と「5. 設定を適用して Meltype を入力メソッドに追加する」)。

### 最新リリース以外の版を使う

Meltype の本体は flake input `meltype-src` (デフォルトは最新リリースのタグ) からビルドする。
`meltype-src` を upstream の pre 版のタグや main のコミットに差し替えると、`fcitx5-meltype` / `ibus-meltype` がその版になる。
Mozc の変換ヘルパーは、差し替えてもリリース版のビルド済みバイナリのまま。

```nix
# flake.nix
inputs.nix-meltype = {
  url = "github:aster-void/nix-meltype";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.meltype-src.url = "github:yksr-melt/Meltype/<pre 版のタグ>"; # main を追うなら github:yksr-melt/Meltype
};
```

更新は自分の flake で `nix flake update nix-meltype`。手元で一度だけ試すなら
`nix build github:aster-void/nix-meltype#fcitx5-meltype --override-input meltype-src github:yksr-melt/Meltype/<rev>`。

### ビルド済みバイナリを使う

本体をソースからビルドせず、upstream のリリース zip のビルド済み本体 `meltype-bin` を使える。
ビルドに時間をかけたくないときや、本体のソースビルドが通らないときに使う。
`meltype-bin` はこの flake が固定している最新リリースの版で、`meltype-src` を差し替えても変わらない。
そのため、上の「最新リリース以外の版を使う」とは同時に使えない。

```nix
# NixOS の設定 (overlay を足した pkgs)
i18n.inputMethod.fcitx5.addons = [ (pkgs.fcitx5-meltype.override { meltype = pkgs.meltype-bin; }) ];
i18n.inputMethod.ibus.engines = [ (pkgs.ibus-meltype.override { meltype = pkgs.meltype-bin; }) ];

# home-manager の設定 (p = pkgs.extend inputs.nix-meltype.overlays.default)
programs.meltype.framework.fcitx5.package = p.fcitx5-meltype.override { meltype = p.meltype-bin; };
programs.meltype.framework.gnomeIbus.package = p.ibus-meltype.override { meltype = p.meltype-bin; };
```

## ライセンス

このリポジトリの Nix 式と CI 設定は [Unlicense](LICENSE) でパブリックドメインに置いている。
upstream の作者 (yksr-melt) を含め誰でも、upstream への取り込み・別ライセンスでの再配布・自分の著作物としての再公開ができる。
ビルドされる Meltype 本体と Mozc は upstream のライセンス (GPL-3.0-or-later / BSD-3-Clause) に従う。
