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

下の文を Claude Code や Codex などのコーディングエージェントにコピペして渡す。

```text
https://raw.githubusercontent.com/aster-void/nix-meltype/main/README.md を読んで、その手順で Meltype をこのマシンに入れて。
- まずこのマシンの Nix 構成 (NixOS か、home-manager か、flake か、設定ファイルの場所) と、今動いている入力メソッド (fcitx5 / IBus、どこから起動しているか) を調べる
- Nix や home-manager が入っていなければ、入れる前に README の「Nix / home-manager が無い場合」に書かれた変更内容を私に説明して確認する
- 設定は既存の Nix 構成に追記する。選んだ方式の手順と README の「ハマりどころ」を全部確かめてから適用する
- fcitx5 と IBus のどちらで使うかは README の「2. fcitx5 と IBus のどちらで使うか決める」で決めて、私に確認する
- 既存の fcitx5 / IBus の設定を上書きする変更や、ディストリの IME を止める変更は、実行前に私に確認する
- 適用後にログインし直しが要るなら私に頼み、戻ってきたら README の「確認」を実行して結果を報告する
```

以下はエージェント向けの説明。

## 提供するパッケージ

対応システムは `x86_64-linux` だけ (upstream のリリース zip が x86_64 だけのため)。

ユーザーが入れるのは `fcitx5-meltype` か `ibus-meltype` のどちらか1つ。

- `packages.x86_64-linux.fcitx5-meltype` (`default`) — fcitx5 アドオン。nixpkgs の fcitx5 に対してソースからビルドする
- `packages.x86_64-linux.ibus-meltype` — IBus エンジン (upstream の Python 製エンジン)。component は `share/ibus/component/meltype.xml`。
  エンジンは nixpkgs の Python と IBus の typelib で動くので、ディストリの ibus-daemon から使うときも python3-gi などは要らない
- `packages.x86_64-linux.meltype` — 本体 (`libMeltypeNative.so`) と Mozc 変換ヘルパー。リリース zip のビルド済みバイナリを使う。
  `fcitx5-meltype` / `ibus-meltype` が store パスで参照するので、個別に入れる必要はない
- `packages.x86_64-linux.{fcitx5,ibus}-meltype-unstable` / `meltype-unstable` — 検証用。本体を upstream のソース
  (flake input `meltype-src`、ロックされたコミット) から NativeAOT でビルドする。Mozc 変換ヘルパーはリリース版のバイナリを使う。
  普段使いには上のリリース版を使う

## Nix / home-manager が無い場合

このリポジトリは、Nix と、home-manager か NixOS のどちらかが入っている前提で使う。
無い環境に入れるとシステムとユーザー設定を大きく変えるので、エージェントは次の内容をユーザーに説明して、了承を得てから入れる。

- Nix のインストール (マルチユーザー): Determinate Nix のインストーラを使う。 `/nix` が作成される。
- home-manager の導入: 導入されていない場合、ミニマルな導入をする。破壊的変更は少ないが、 `/nix/` を指す symlink が `~` 以下に作られることがある。
- 入力メソッドの切り替え (fcitx5 で使う場合): ディストリの IBus / fcitx5 を止めて nixpkgs の fcitx5 に切り替えるので、既存の IME の設定 (辞書・学習データ・キー設定) は引き継がれない。
  ディストリで入れた fcitx5 のアドオン (fcitx5-mozc など) も nixpkgs の fcitx5 からは読めない。Meltype とは別に使い続けるなら、
  nixpkgs の同じアドオンを `fcitx5.addons` に足す。

## 導入手順

### 0. セットアップ

Nix が無い場合は Determinate Nix のインストーラで入れる。sudo のパスワードが要るので、ユーザーに実行してもらう。
flakes は最初から有効になる。

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

non-NixOS で既存の Home Manager セットアップがない場合は、standalone の flake 構成で作る (NixOS では作らず、NixOS の設定に書く)。
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

module から `inputs` を参照できるように、`outputs = { nixpkgs, ... }@inputs:` で受け取り、
`extraSpecialArgs = { inherit inputs; };` (home-manager) / `specialArgs = { inherit inputs; };` (NixOS) で渡す。

### 2. fcitx5 と IBus のどちらで使うか決める

上から順に判定し、最初に当てはまったものを使う。決めたらユーザーに確認する。

1. すでに fcitx5 を使っている → fcitx5
2. GNOME → IBus。GNOME は IBus を組み込みで扱うので、入力ソースの切り替えと候補ウィンドウが追加の設定なしで動く。
   non-NixOS ではディストリの IBus に Meltype を足すだけなので、既存の IBus エンジン (Mozc など) と設定も残る
3. それ以外 → fcitx5

- fcitx5: 「3. fcitx5 で使う場合」へ
- IBus: 「4. IBus で使う場合」へ

### 3. fcitx5 で使う場合

#### 3-1. fcitx5 とアドオンを有効にする

下の内容を home-manager (non-NixOS を含む) か NixOS のどちらか一方の module に書く。オプション名は両方で同じ。

```nix
{ inputs, pkgs, ... }:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = [ inputs.nix-meltype.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    # Wayland セッション (GNOME / KDE Plasma) では true。GTK_IM_MODULE / QT_IM_MODULE を設定せず、
    # アプリは Wayland の text-input で IME に繋がる (ディストリのアプリにディストリの fcitx5-gtk / fcitx5-qt が要らない)
    fcitx5.waylandFrontend = true;
  };
}
```

non-NixOS の home-manager では、さらに環境変数を GUI セッションに届ける。fcitx5 module は `XMODIFIERS` などを
`home.sessionVariables` (`hm-session-vars.sh`) にしか書かないので、ログインシェルがこれを読まない限り GUI アプリに届かない。
GDM と Plasma はどちらも `~/.config/environment.d` を取り込むので、`systemd.user.sessionVariables` に転記する。
`home.sessionVariables` 全体を転記しない (値の型やシェル構文が environment.d で使えない変数が混ざる)。

```nix
{ config, lib, ... }:
{
  systemd.user.sessionVariables = lib.getAttrs (lib.filter (n: config.home.sessionVariables ? ${n}) [
    "GTK_IM_MODULE"
    "QT_IM_MODULE"
    "XMODIFIERS"
    "SDL_IM_MODULE"
    "GLFW_IM_MODULE"
  ]) config.home.sessionVariables;
}
```

KDE Plasma (Wayland) では、fcitx5 を KWin に起動させる。KWin は Wayland の input method プロトコルを自分が起動した
プロセスにしか渡さないので、home-manager の systemd user service (`fcitx5-daemon`) で起動した fcitx5 では入力できない。
home-manager では service を止め、KWin が起動する IME を kwinrc に書く。NixOS では service が作られないので、
ログインし直した後にシステム設定 →「仮想キーボード」で Fcitx 5 を選ぶ。

```nix
{ config, ... }:
{
  i18n.inputMethod.fcitx5.systemd.enable = false;
  # kwinrc は KWin 自身も書き換えるので、xdg.configFile でファイルごと管理せずキー単位で書く
  qt.kde.settings.kwinrc.Wayland.InputMethod =
    "${config.i18n.inputMethod.package}/share/applications/org.fcitx.Fcitx5.desktop";
}
```

#### 3-2. 既存の IME を止める

ディストリの IBus / fcitx5 が動いていると、nixpkgs の fcitx5 と取り合いになる。止める前にユーザーに確認する。
ディストリのパッケージは消さず、ユーザー単位の設定で起動を止める (戻すときは追加したファイル・設定を消すだけで済む)。

- XDG autostart で起動しているもの: `/etc/xdg/autostart/` の該当 `.desktop` と同名のファイルを
  `~/.config/autostart/` に作り、`Hidden=true` だけを書く
- GNOME: `org.gnome.desktop.input-sources sources` から `('ibus', ...)` のエントリだけを外す。
  `('xkb', ...)` はキーボード配列の指定なので残す。
  GNOME Wayland のアプリの入力は gnome-shell が IBus の D-Bus 名 (`org.freedesktop.IBus`) へ送る。nixpkgs の fcitx5 は
  IBus 互換のフロントエンドでこの名前を取り、gnome-shell がそのまま候補ウィンドウを描くので、kimpanel などの拡張は要らない。
  ディストリの ibus-daemon (systemd user unit `org.freedesktop.IBus.session.GNOME.service`) は fcitx5 に名前を取られて
  毎回 kill され、unit が failed で残るので mask する (`~/.config/systemd/user/` に同名の空ファイルを置く。
  home-manager なら `xdg.configFile."systemd/user/org.freedesktop.IBus.session.GNOME.service".text = "";`)
- KDE Plasma (Wayland): KWin が起動する IME は 3-1 の kwinrc の設定で nixpkgs の fcitx5 に変わる。
  システム設定 →「仮想キーボード」で別の IME を選び直すと kwinrc が上書きされる
- 動作中のプロセス: `ibus exit` / `pkill -x fcitx5` で止めてから、nixpkgs の fcitx5 を起動する

#### 3-3. Meltype を入力メソッドに追加する

入力メソッド名は `meltype`。追加の方法は、fcitx5 の入力メソッドの設定を今どう管理しているかで決める。

- Nix の設定に `i18n.inputMethod.fcitx5.settings.inputMethod` がすでにある → そこに追記して適用する
- それ以外 → 適用してログインし直した後に、`~/.config/fcitx5/profile` を書き換える。fcitx5 は終了時に profile を書き出して
  手での変更を上書きするので、fcitx5 を止めてから書き換えて起動し直す。ユーザーに GUI で頼むなら `fcitx5-configtool` →「入力メソッド」

`settings.inputMethod` を新しく書き始めない。「ハマりどころ」の通り、home-manager では `~/.config/fcitx5` 全体が読み取り専用になり、
NixOS では既存の `~/.config/fcitx5/profile` に負けて反映されない。

例の `us` / `keyboard-us` はユーザーのキーボード配列に合わせる (JIS なら `jp` / `keyboard-jp`)。
既定の入力メソッドを Meltype にするなら `DefaultIM` も `meltype` にする。

```ini
# ~/.config/fcitx5/profile
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=meltype

[Groups/0/Items/0]
Name=keyboard-us

[Groups/0/Items/1]
Name=meltype

[GroupOrder]
0=Default
```

```nix
# すでに settings.inputMethod を書いている場合
i18n.inputMethod.fcitx5.settings.inputMethod = {
  GroupOrder."0" = "Default";
  "Groups/0" = {
    Name = "Default";
    "Default Layout" = "us";
    DefaultIM = "meltype";
  };
  "Groups/0/Items/0".Name = "keyboard-us";
  "Groups/0/Items/1".Name = "meltype";
};
```

### 4. IBus で使う場合

ibus-daemon は、環境変数 `IBUS_COMPONENT_PATH` に並べたディレクトリから component (`*.xml`) を読む。
`ibus-meltype` の component は `share/ibus/component/` にある。

#### NixOS

```nix
{ inputs, pkgs, ... }:
{
  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus.engines = [ inputs.nix-meltype.packages.${pkgs.stdenv.hostPlatform.system}.ibus-meltype ];
  };
}
```

#### non-NixOS (home-manager)

ディストリの ibus-daemon をそのまま使い、起動時に次の2つを渡す。

- 環境変数 `IBUS_COMPONENT_PATH`: 設定すると既定の `/usr/share/ibus/component` を置き換えるので、それも並べる
- オプション `--cache=refresh`: 既定 (`auto`) の ibus-daemon は、システムのキャッシュ `/var/cache/ibus/bus/registry` が
  古くなっていなければそれだけを読み、`IBUS_COMPONENT_PATH` の中身と照合しない。そのため Meltype が一覧に出ない

GNOME は systemd user unit `org.freedesktop.IBus.session.GNOME.service` から ibus-daemon を起動するので、drop-in で上書きする。
`ExecStart` はディストリの unit (`systemctl --user cat org.freedesktop.IBus.session.GNOME.service`) の行に `--cache=refresh` を足したものにする。
下の例は Fedora の unit から作ったもの。

```nix
{ inputs, pkgs, ... }:
let
  ibus-meltype = inputs.nix-meltype.packages.${pkgs.stdenv.hostPlatform.system}.ibus-meltype;
in
{
  xdg.configFile."systemd/user/org.freedesktop.IBus.session.GNOME.service.d/meltype.conf".text = ''
    [Service]
    Environment=IBUS_COMPONENT_PATH=/usr/share/ibus/component:${ibus-meltype}/share/ibus/component
    ExecStart=
    ExecStart=sh -c 'exec /usr/bin/ibus-daemon --panel disable --cache=refresh $([ "$XDG_SESSION_TYPE" = "x11" ] && echo "--xim")'
  '';
}
```

GNOME 以外では、ibus-daemon を起動している箇所 (XDG autostart、KDE Plasma は「仮想キーボード」の設定) を調べて、同じ2つを渡す。

#### NixOS / non-NixOS 共通

fcitx5 (Nix・ディストリどちらでも) を起動している設定があれば外す。対象は `i18n.inputMethod` の fcitx5 の設定、
autostart (ディストリのものは「3-2. 既存の IME を止める」と同じく `Hidden=true` で止める)、
fcitx5 向けの環境変数 (`GTK_IM_MODULE=fcitx` など。残っているとアプリが止めた fcitx5 に繋ごうとして入力できない)。
IBus を止める設定 (`Hidden=true` の autostart や、mask した unit) があれば外す。

適用してログインし直した後に、入力ソースに Meltype を追加する。GNOME では「設定」→「キーボード」→「入力ソース」の
日本語から Meltype を選ぶか、`org.gnome.desktop.input-sources sources` に `('ibus', 'meltype')` を足す。

### 5. 確認してユーザーに完了を伝える

「確認」の手順を実行してから、ユーザーに完了を伝え、GUI アプリで打って試してもらう。

## ハマりどころ

### 共通

- 環境変数と入力メソッドの変更は、ログインし直すまで既存の GUI セッションに反映されない
- aarch64 などでは `packages.<system>` が存在しないので、評価時に attribute missing エラーになる
- `pkgs.system` は非推奨。`pkgs.stdenv.hostPlatform.system` を使う

### fcitx5

- ディストリの fcitx5 では動かない。アドオンは nixpkgs の fcitx5 に対してビルドしているので、`/usr/bin/fcitx5` からは読めない。
  ディストリの fcitx5 が XDG autostart や imsettings から起動されていると、home-manager の fcitx5
  (systemd user service `fcitx5-daemon`) と取り合いになる。止め方は「3-2. 既存の IME を止める」
- `nixpkgs.follows` を外さない。外すと、アドオンのビルドに使った fcitx5 と実行する fcitx5 のバージョンがずれる
- home-manager の `fcitx5-daemon` が Wayland のソケットより先に起動すると、`journalctl --user -u fcitx5-daemon` に
  `Failed to open wayland connection` が出て、fcitx5 は動いているのに入力できない。ソケットを待ってから起動させる:
  `systemd.user.services.fcitx5-daemon.Service.ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 50); do [ -S \"$XDG_RUNTIME_DIR/wayland-0\" ] && exit 0; sleep 0.1; done; exit 1'";`
- `QT_PLUGIN_PATH` (module が `hm-session-vars.sh` に入れる nixpkgs の Qt プラグインのパス) は environment.d に転記しない。
  ディストリの Qt アプリが別バージョンの Qt で作られたプラグインを読みにいく
- GNOME の入力ソースに IBus の日本語エンジン (Mozc / Anthy など) が残っていると、fcitx5 と IBus の両方がキーを受け取る
- home-manager で宣言的に `settings.inputMethod` を書くと、`~/.config/fcitx5` 全体が store への読み取り専用 symlink になる。
  既存の `~/.config/fcitx5` の内容は使われなくなり、`fcitx5-configtool` で変えた設定も保存できなくなる。
- NixOS で宣言的に `settings.inputMethod` を書くと、書き出し先は `/etc/xdg/fcitx5/profile` になる。
  ユーザーの `~/.config/fcitx5/profile` が存在するとそちらが優先されるので、宣言した内容は反映されない

## 確認

### fcitx5

```sh
# 動いている fcitx5 の PID。起動元 (systemd / KWin / autostart) によらず、D-Bus 名を持つプロセスから取る。
# nixpkgs の fcitx5 はプロセス名が .fcitx5-wrapped なので、pgrep -x fcitx5 では見つからない
pid=$(busctl --user status org.fcitx.Fcitx5 | sed -n 's/^PID=//p')

# (KDE Plasma Wayland) KWin が起動しているか。親が kwin_wayland で、WAYLAND_SOCKET がある
ps -o comm= -p "$(ps -o ppid= -p "$pid")"
tr '\0' '\n' < /proc/$pid/environ | grep WAYLAND_SOCKET

# (GNOME) gnome-shell が fcitx5 の IBus 互換フロントエンドに繋がっているか。PID が上の fcitx5 と同じ
busctl --user status org.freedesktop.IBus | sed -n 's/^PID=//p'

# 動いている fcitx5 が /nix/store のものか。/usr/bin/fcitx5 ならディストリの fcitx5 が動いている
readlink /proc/$pid/exe

# fcitx5 が Meltype のアドオンと本体を読み込んでいるか。meltype.so と libMeltypeNative.so の2行が出る
grep -o '/nix/store/[^ ]*meltype[^ ]*' /proc/$pid/maps | sort -u

# GUI セッションに環境変数が届いているか。waylandFrontend = true のときは GTK_IM_MODULE / QT_IM_MODULE を
# 設定しないので、XMODIFIERS=@im=fcitx が出ればよい。GNOME でディストリが設定する QT_IM_MODULE=ibus は、
# fcitx5 の IBus 互換フロントエンドに繋がるのでそのままでよい
systemctl --user show-environment | grep -E 'GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS'
```

`fcitx5-remote -n` はフォーカス中の入力欄の入力メソッドを返すので、エージェントのシェルから実行しても空になる。
Meltype に切り替えて変換できるかは、ユーザーに GUI アプリで打ってもらって確かめる。

アドオンが読み込まれていなければ、`journalctl --user -u fcitx5-daemon` か、`fcitx5 -r --verbose '*=5'` を端末から起動して、
アドオン読み込み時のエラーを見る。

### IBus

```sh
# ibus コマンドは WAYLAND_DISPLAY (X11 では DISPLAY) から接続先を決める。GUI セッション外のシェル (SSH など) では
# GUI セッションと同じ値 (例: wayland-0) を設定しないと "Can't connect to IBus" になる

# ibus-daemon が Meltype の component を読み込んでいるか。meltype が出る
ibus list-engine | grep -w meltype

# (non-NixOS の GNOME) ibus-daemon に IBUS_COMPONENT_PATH と --cache=refresh が渡っているか
pid=$(systemctl --user show -p MainPID --value org.freedesktop.IBus.session.GNOME.service)
tr '\0' '\n' < /proc/$pid/environ | grep IBUS_COMPONENT_PATH
tr '\0' ' ' < /proc/$pid/cmdline

# Meltype に切り替えた後、エンジンのプロセスが /nix/store のラッパーから起動しているか
pgrep -af ibus-engine-meltype
```

Meltype に切り替えて変換できるかは、ユーザーに GUI アプリで打ってもらって確かめる。

## 実行時のデータ

設定と学習データは `~/.local/share/Meltype`。Nix の管理外なので、パッケージを消しても残る。

## 更新 (このリポジトリのメンテナンス)

`packages/meltype/default.nix` の `version` と `hash`、`packages/fcitx5-meltype/default.nix` のソースの `hash` を書き換える。
`nix build .#fcitx5-meltype` で upstream のテスト (fcitx5 の testfrontend でキー入力と確定文字列を確かめる) が走る。
`nix build .#ibus-meltype` では upstream の IBus 向けテスト (Mozc 込みの変換) と、専用の ibus-daemon に component を読ませて
かなが出るかの確認 (`packages/ibus-meltype/check-component.py`) が走る。

検証用の `*-unstable` は CI (`.github/workflows/update-unstable.yml`) が毎日 `nix flake update meltype-src` で
upstream main の HEAD に更新し、`fcitx5-meltype-unstable` と `ibus-meltype-unstable` のビルドが通ったときだけ main に push する。
特定のコミットを試すときは `--override-input meltype-src github:yksr-melt/Meltype/<rev>` を付けてビルドする。
HEAD の本体とリリース版の Mozc ヘルパーの組み合わせは、IBus 版のテストだけが検証する (fcitx5 版のテストは Mozc 無しで走る)。

## ライセンス

このリポジトリの Nix 式と CI 設定は [Unlicense](LICENSE) でパブリックドメインに置いている。
upstream の作者 (yksr-melt) を含め誰でも、upstream への取り込み・別ライセンスでの再配布・自分の著作物としての再公開ができる。
ビルドされる Meltype 本体と Mozc は upstream のライセンス (GPL-3.0-or-later / BSD-3-Clause) に従う。
