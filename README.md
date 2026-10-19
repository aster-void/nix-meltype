# nix-meltype

[Meltype](https://github.com/yksr-melt/Meltype) の fcitx5 アドオンを Nix で入れるための flake。

## これは何？

Meltype は、半角/全角キーで切り替えずに日本語と英語を混ぜて打てる日本語入力。
ローマ字で打つと、英単語は英字のまま、日本語はかな漢字に変換される。

```
kyouhagoogledekensaku  →  今日はgoogleで検索
```

upstream の Linux 版はインストールスクリプトで入れる。スクリプトは Ubuntu を前提にしていて、`/opt` とシステムの fcitx5 にファイルを置く。
この flake は、それを Nix のパッケージにしたもの。NixOS や、home-manager を使う他のディストリで、システムを汚さずに入れられる。
使い方は upstream の [USAGE.md](https://github.com/yksr-melt/Meltype/blob/main/docs/USAGE.md) を参照。

## インストール

下の文を Claude Code や Codex などのコーディングエージェントにコピペして渡す。

```text
https://raw.githubusercontent.com/aster-void/nix-meltype/main/README.md を読んで、その手順で Meltype (fcitx5 アドオン) をこのマシンに入れて。
- まずこのマシンの Nix 構成 (NixOS か、home-manager か、flake か、設定ファイルの場所) と、今動いている入力メソッド (fcitx5 / IBus、どこから起動しているか) を調べる
- Nix や home-manager が入っていなければ、入れる前に README の「Nix / home-manager が無い場合」に書かれた変更内容を私に説明して確認する
- 設定は既存の Nix 構成に追記する。README の「ハマりどころ」を全部確かめてから適用する
- 既存の fcitx5 設定を上書きする変更や、ディストリの IME を止める変更は、実行前に私に確認する
- 適用後にログインし直しが要るなら私に頼み、戻ってきたら README の「確認」を実行して結果を報告する
```

以下はエージェント向けの説明。

## 提供するパッケージ

対応システムは `x86_64-linux` だけ (upstream のリリース zip が x86_64 だけのため)。

- `packages.x86_64-linux.fcitx5-meltype` (`default`) — fcitx5 アドオン。nixpkgs の fcitx5 に対してソースからビルドする。
  ユーザーが入れるのはこれだけでよい
- `packages.x86_64-linux.meltype` — 本体 (`libMeltypeNative.so`) と Mozc 変換ヘルパー。リリース zip のビルド済みバイナリを使う。
  `fcitx5-meltype` が store パスで参照するので、個別に入れる必要はない
- `packages.x86_64-linux.fcitx5-meltype-unstable` / `meltype-unstable` — 検証用。本体を upstream のソース
  (flake input `meltype-src`、ロックされたコミット) から NativeAOT でビルドする。Mozc 変換ヘルパーはリリース版のバイナリを使う。
  普段使いには上のリリース版を使う

IBus エンジンはパッケージ化していない。ibus-daemon はユーザーディレクトリのコンポーネントを読まないため、
non-NixOS の home-manager から登録する手段がない。IBus しか使えない環境では、このリポジトリは使えない。

## Nix / home-manager が無い場合

このリポジトリは、Nix と、home-manager か NixOS のどちらかが入っている前提で使う。
無い環境に入れるとシステムとユーザー設定を大きく変えるので、エージェントは次の内容をユーザーに説明して、了承を得てから入れる。

- Nix のインストール (マルチユーザー): Determinate Nix のインストーラを使う。 `/nix` が作成される。
- home-manager の導入: 導入されていない場合、ミニマルな導入をする。破壊的変更は少ないが、 `/nix/` を指す symlink が `~` 以下に作られることがある。
- 入力メソッドの切り替え: ディストリの IBus / fcitx5 を止めて nixpkgs の fcitx5 に切り替えるので、既存の IME の設定 (辞書・学習データ・キー設定) は引き継がれない。

## 導入手順

### 0. セットアップ

Nix が無い場合は Determinate Nix のインストーラで入れる。sudo のパスワードが要るので、ユーザーに実行してもらう。
flakes は最初から有効になる。

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

既存の Home Manager セットアップがない場合は、standalone の flake 構成で作る。
`~/.config/home-manager/{flake.nix,home.nix}` が生成されるので、以降の手順はそこに書く。

```sh
nix run home-manager/master -- init --switch
```

設定の適用は `home-manager switch`。

### 1. flake input を足す

```nix
inputs.nix-meltype = {
  url = "github:aster-void/nix-meltype";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

module から `inputs` を参照できるように、`extraSpecialArgs = { inherit inputs; };` (home-manager) /
`specialArgs = { inherit inputs; };` (NixOS) で渡す。

### 2. fcitx5 とアドオンを有効にする

home-manager (non-NixOS を含む) でも NixOS でも、同じ内容をそれぞれの module に書く。
fcitx5 を有効にするのは home-manager と NixOS のどちらか一方だけにする。

```nix
{ inputs, pkgs, ... }:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = [ inputs.nix-meltype.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  };
}
```

### 3. 既存の IME を止める

ディストリの IBus / fcitx5 が動いていると、nixpkgs の fcitx5 と取り合いになる。止める前にユーザーに確認する。
ディストリのパッケージは消さず、ユーザー単位の設定で起動を止める (戻すときは追加したファイル・設定を消すだけで済む)。

- XDG autostart で起動しているもの: `/etc/xdg/autostart/` の該当 `.desktop` と同名のファイルを
  `~/.config/autostart/` に作り、`Hidden=true` だけを書く
- GNOME: `org.gnome.desktop.input-sources sources` から `('ibus', ...)` のエントリだけを外す。
  `('xkb', ...)` はキーボード配列の指定なので残す。
  ibus-daemon 自体は gnome-shell が起動するが、環境変数で GTK / Qt アプリは fcitx5 に繋がる
- KDE Plasma (Wayland): システム設定 →「仮想キーボード」で選んだ IME を KWin が起動する。nixpkgs の fcitx5 を選ぶ
- 動作中のプロセス: `ibus exit` / `pkill -x fcitx5` で止めてから、nixpkgs の fcitx5 を起動する

### 4. Meltype を入力メソッドに追加する

入力メソッド名は `meltype`。適用してログインし直した後に、どれかで追加する。

- 設定ファイル: `~/.config/fcitx5/profile` を書き換える (fcitx5 の設定が home-manager 管理されていない場合はこちらを選択)。
  fcitx5 は終了時に profile を書き出して手での変更を上書きするので、`pkill -x fcitx5` で止めてから書き換えて起動し直す
- GUI: `fcitx5-configtool` →「入力メソッド」で Meltypeを追加する
- Nix管理: `i18n.inputMethod.fcitx5.settings.inputMethod` (home-manager / NixOS 共通) に書く

例の `us` / `keyboard-us` はユーザーのキーボード配列に合わせる (JIS なら `jp` / `keyboard-jp`)。

```nix
i18n.inputMethod.fcitx5.settings.inputMethod = {
  GroupOrder."0" = "Default";
  "Groups/0" = {
    Name = "Default";
    "Default Layout" = "us";
    DefaultIM = "meltype";
  };
  "Groups/0/Items/0".Name = "keyboard-us";
  "Groups/0/Items/1".Name = "meltype"; # <- この行を追記
};
```

### 5. ユーザーに完了を伝え、試してもらう

## ハマりどころ

- ディストリの fcitx5 では動かない。アドオンは nixpkgs の fcitx5 に対してビルドしているので、`/usr/bin/fcitx5` からは読めない。
  ディストリの fcitx5 が XDG autostart や imsettings から起動されていると、home-manager の fcitx5
  (systemd user service `fcitx5-daemon`) と取り合いになる。止め方は「3. 既存の IME を止める」
- `nixpkgs.follows` を外さない。外すと、アドオンのビルドに使った fcitx5 と実行する fcitx5 のバージョンがずれる
- home-manager の環境変数 (`GTK_IM_MODULE` / `QT_IM_MODULE` / `XMODIFIERS` / `QT_PLUGIN_PATH`) は
  `home.sessionVariables` に入り、`hm-session-vars.sh` をログインシェルが読んだときだけ GUI セッションに届く。
  non-NixOS でログインシェルを home-manager が管理していない場合や、ログインシェルが fish で `programs.fish` を
  有効にしていない場合は、GUI アプリに環境変数が届かず、fcitx5 が動いていても入力できない
- GNOME の入力ソースに IBus の日本語エンジン (Mozc / Anthy など) が残っていると、fcitx5 と IBus の両方がキーを受け取る
- home-manager で宣言的に `settings.inputMethod` を書くと、`~/.config/fcitx5` 全体が store への読み取り専用 symlink になる。
  既存の `~/.config/fcitx5` の内容は使われなくなり、`fcitx5-configtool` で変えた設定も保存できなくなる。
- NixOS で宣言的に `settings.inputMethod` を書くと、書き出し先は `/etc/xdg/fcitx5/profile` になる。
  ユーザーの `~/.config/fcitx5/profile` が存在するとそちらが優先されるので、宣言した内容は反映されない
- 環境変数と入力メソッドの変更は、ログインし直すまで既存の GUI セッションに反映されない
- aarch64 などでは `packages.<system>` が存在しないので、評価時に attribute missing エラーになる
- `pkgs.system` は非推奨。`pkgs.stdenv.hostPlatform.system` を使う

## 確認

```sh
# 動いている fcitx5 の PID。nixpkgs の fcitx5 はプロセス名が .fcitx5-wrapped なので、pgrep -x fcitx5 では見つからない
# (home-manager の systemd user service で起動している場合。NixOS では pgrep -f bin/fcitx5)
pid=$(systemctl --user show -p MainPID --value fcitx5-daemon)

# 動いている fcitx5 が /nix/store のものか。/usr/bin/fcitx5 ならディストリの fcitx5 が動いている
readlink /proc/$pid/exe

# fcitx5 が Meltype のアドオンと本体を読み込んでいるか。meltype.so と libMeltypeNative.so の2行が出る
grep -o '/nix/store/[^ ]*meltype[^ ]*' /proc/$pid/maps | sort -u

# GUI セッションに環境変数が届いているか。GUI から起動したアプリ (ターミナルなど) の中で実行する。
# waylandFrontend = true のときは GTK_IM_MODULE / QT_IM_MODULE を設定しないので、XMODIFIERS だけが出る
echo $GTK_IM_MODULE $QT_IM_MODULE $XMODIFIERS
```

`fcitx5-remote -n` はフォーカス中の入力欄の入力メソッドを返すので、エージェントのシェルから実行しても空になる。
Meltype に切り替えて変換できるかは、ユーザーに GUI アプリで打ってもらって確かめる。

アドオンが読み込まれていなければ、`journalctl --user -u fcitx5-daemon` か、`fcitx5 -r --verbose '*=5'` を端末から起動して、
アドオン読み込み時のエラーを見る。

## 実行時のデータ

設定と学習データは `~/.local/share/Meltype`。Nix の管理外なので、パッケージを消しても残る。

## 更新 (このリポジトリのメンテナンス)

`packages/meltype/default.nix` の `version` と `hash`、`packages/fcitx5-meltype/default.nix` のソースの `hash` を書き換える。
`nix build .#fcitx5-meltype` で upstream のテスト (fcitx5 の testfrontend でキー入力と確定文字列を確かめる) が走る。

検証用の `*-unstable` は CI (`.github/workflows/update-unstable.yml`) が毎日 `nix flake update meltype-src` で
upstream main の HEAD に更新し、`fcitx5-meltype-unstable` のビルドが通ったときだけ main に push する。
特定のコミットを試すときは `--override-input meltype-src github:yksr-melt/Meltype/<rev>` を付けてビルドする。
upstream のテストは Mozc 無しで走るので、HEAD の本体とリリース版の Mozc ヘルパーの組み合わせは検証されない。
