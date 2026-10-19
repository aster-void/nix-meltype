# nix-meltype のインストール (エージェント向け)

## 提供するもの

対応システムは `x86_64-linux` と `aarch64-linux` (upstream がリリース zip を出している CPU)。

- `homeModules.default` — home-manager module (`programs.meltype`)。Meltype を fcitx5 のアドオンかディストリの IBus に足し、
  ディストリのデスクトップと nixpkgs の IME を噛み合わせる設定 (環境変数・KWin・ディストリの ibus-daemon) を書く。
  `i18n.inputMethod` の `enable` / `type` は設定しない
- `packages.<system>.fcitx5-meltype` (`default`) — fcitx5 アドオン。nixpkgs の fcitx5 に対してソースからビルドする
- `packages.<system>.ibus-meltype` — IBus エンジン (upstream の Python 製エンジン)。component は `share/ibus/component/meltype.xml`。
  エンジンは nixpkgs の Python と IBus の typelib で動くので、ディストリの ibus-daemon から使うときも python3-gi などは要らない
- `packages.<system>.meltype` — 本体 (`libMeltypeNative.so`) と Mozc 変換ヘルパー。リリース zip のビルド済みバイナリを使う。
  `fcitx5-meltype` / `ibus-meltype` が store パスで参照するので、個別に入れる必要はない
- `packages.<system>.{fcitx5,ibus}-meltype-unstable` / `meltype-unstable` — 検証用。本体を upstream のソース
  (flake input `meltype-src`、ロックされたコミット) から NativeAOT でビルドする。普段使いには上のリリース版を使う

## Nix / home-manager が無い場合

このリポジトリは、Nix と、home-manager か NixOS のどちらかが入っている前提で使う。
無い環境に入れるとシステムとユーザー設定を大きく変えるので、エージェントは次の内容をユーザーに説明して、了承を得てから入れる。

- Nix のインストール (マルチユーザー): Determinate Nix のインストーラを使う。 `/nix` が作成される。
- home-manager の導入: 導入されていない場合、ミニマルな導入をする。破壊的変更は少ないが、 `/nix/` を指す symlink が `~` 以下に作られることがある。
- 入力メソッドの切り替え (fcitx5 で使う場合): ディストリの IBus / fcitx5 を止めて nixpkgs の fcitx5 に切り替える。
  IBus から切り替えると、IBus 側の設定 (入力ソース・キー設定) は使われなくなる。ディストリの fcitx5 から切り替えると、
  `~/.config/fcitx5` はそのまま読まれる。
  ディストリで入れた fcitx5 のアドオン (fcitx5-mozc など) も nixpkgs の fcitx5 からは読めない。Meltype とは別に使い続けるなら、
  nixpkgs の同じアドオンを `i18n.inputMethod.fcitx5.addons` に足す。

## 導入手順

### 0. セットアップ

Nix が無い場合は Determinate Nix のインストーラで入れる。sudo のパスワードが要るので、ユーザーに実行してもらう。
flakes は最初から有効になる。

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

non-NixOS で既存の Home Manager セットアップがない場合は、standalone の flake 構成で作る。
`~/.config/home-manager/{flake.nix,home.nix}` が生成され、設定の適用は `home-manager switch`。

```sh
nix run home-manager/master -- init --switch
```

### 1. どこに書くかを決める

- home-manager がある → home-manager module。NixOS 上の home-manager でもこれを使う
- NixOS で home-manager が無い → NixOS の `i18n.inputMethod` に直接書く (「3. 設定を書く」の NixOS の節)

### 2. fcitx5 と IBus のどちらで使うか決める

上から順に判定し、最初に当てはまったものを使う。決めたらユーザーに確認する。

1. すでに fcitx5 を使っている → fcitx5
2. GNOME → IBus。GNOME は IBus を組み込みで扱うので、入力ソースの切り替えと候補ウィンドウが追加の設定なしで動く。
   non-NixOS ではディストリの IBus に Meltype を足すだけなので、既存の IBus エンジン (Mozc など) と設定も残る
3. それ以外 → fcitx5

home-manager module の IBus はディストリの ibus-daemon (`/usr/bin/ibus-daemon`) を使う。NixOS で IBus にするなら、
home-manager があっても NixOS の節に書く。

### 3. 設定を書く

flake input を足す。

```nix
inputs.nix-meltype = {
  url = "github:aster-void/nix-meltype";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

#### home-manager

module を読み込む。standalone では `homeManagerConfiguration` の `modules`、NixOS の module として使う
home-manager では `home-manager.sharedModules` に `inputs.nix-meltype.homeModules.default` を足す。

```nix
# fcitx5。アドオンは programs.meltype が i18n.inputMethod.fcitx5.addons に足す
i18n.inputMethod = {
  enable = true;
  type = "fcitx5";
  fcitx5.waylandFrontend = true;
};
programs.meltype = {
  enable = true;
  framework.fcitx5.desktopWorkaround = "gnome"; # "gnome" | "plasma" | "none"
};
```

```nix
# IBus (ディストリの GNOME の ibus-daemon に足す)
programs.meltype = {
  enable = true;
  framework.gnomeIbus = { };
};
```

#### NixOS

module から `inputs` を参照できるように、`outputs = { nixpkgs, ... }@inputs:` で受け取り、`specialArgs = { inherit inputs; };` で渡す。

```nix
{ inputs, pkgs, ... }:
let
  meltype = inputs.nix-meltype.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  i18n.inputMethod = {
    enable = true;
    # fcitx5
    type = "fcitx5";
    fcitx5.addons = [ meltype.fcitx5-meltype ];
    fcitx5.waylandFrontend = true;
    # IBus
    # type = "ibus";
    # ibus.engines = [ meltype.ibus-meltype ];
  };
}
```

KDE Plasma で fcitx5 を使うなら、ログインし直した後にシステム設定 →「仮想キーボード」で Fcitx 5 を選ぶ。

### 4. 既存の IME を止める

ディストリの IBus / fcitx5 が動いていると、使う側と取り合いになる。止める前にユーザーに確認する。
ディストリのパッケージは消さず、ユーザー単位の設定で起動を止める (戻すときは追加したファイル・設定を消すだけで済む)。

fcitx5 で使う場合:

- XDG autostart で起動しているもの: `/etc/xdg/autostart/` の該当 `.desktop` と同名のファイルを
  `~/.config/autostart/` に作り、`Hidden=true` だけを書く
- GNOME: `org.gnome.desktop.input-sources sources` から `('ibus', ...)` のエントリだけを外す。
  `('xkb', ...)` はキーボード配列の指定なので残す。候補ウィンドウは gnome-shell が描くので、kimpanel などの拡張は要らない
- 動作中のプロセス: `ibus exit` / `pkill -x fcitx5` で止める。nixpkgs の fcitx5 はログインし直すと起動する
  (KDE Plasma では KWin が起動したものでないと入力できないので、手で起動しない)

IBus で使う場合: fcitx5 (Nix・ディストリどちらでも) を起動している設定を外す。対象は `i18n.inputMethod` の fcitx5 の設定、
autostart (ディストリのものは上と同じく `Hidden=true` で止める)、fcitx5 向けの環境変数
(`GTK_IM_MODULE=fcitx` など。残っているとアプリが止めた fcitx5 に繋ごうとして入力できない)。
IBus を止める設定 (`Hidden=true` の autostart や、mask した unit) があれば外す。

### 5. 設定を適用して Meltype を入力メソッドに追加する

#### fcitx5

入力メソッド名は `meltype`。追加の方法は、fcitx5 の入力メソッドの設定を今どう管理しているかで決める。

- Nix の設定に `i18n.inputMethod.fcitx5.settings.inputMethod` がすでにある → そこに追記して適用する
- それ以外 → 設定を適用し、fcitx5 が動いていない間 (4 で止めた後、ログインし直す前) に `~/.config/fcitx5/profile` を書き換える。
  fcitx5 は終了時に profile を書き出すので、動いている間に書き換えると上書きされる。
  ログインし直した後にユーザーに GUI で頼むなら `fcitx5-configtool` →「入力メソッド」

`settings.inputMethod` を新しく書き始めない。home-manager では `~/.config/fcitx5` 全体が store への読み取り専用 symlink になり、
既存の設定は使われなくなり、`fcitx5-configtool` で変えた設定も保存できなくなる。NixOS では書き出し先が
`/etc/xdg/fcitx5/profile` になり、既存の `~/.config/fcitx5/profile` のほうが優先されるので反映されない。

例の `us` / `keyboard-us` はユーザーのキーボード配列に合わせる (JIS なら `jp` / `keyboard-jp`)。
既定の入力メソッドを Meltype にするなら `DefaultIM` も `meltype` にする。
`settings.inputMethod` に書くときも同じ構造を attrset で書く。

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

#### IBus

設定を適用してログインし直した後に、入力ソースに Meltype を追加する。GNOME では「設定」→「キーボード」→「入力ソース」の
日本語から Meltype を選ぶか、`org.gnome.desktop.input-sources sources` に `('ibus', 'meltype')` を足す。

### 6. 確認してユーザーに完了を伝える

「確認」の手順を実行してから、ユーザーに完了を伝え、GUI アプリで打って試してもらう。

## ハマりどころ

- 環境変数と入力メソッドの変更は、ログインし直すまで既存の GUI セッションに反映されない
- 対応システム以外 (riscv64 など) では `packages.<system>` が存在しないので、評価時に attribute missing エラーになる
- fcitx5 はディストリの fcitx5 では動かない。アドオンは nixpkgs の fcitx5 に対してビルドしているので、`/usr/bin/fcitx5` からは読めない
- `nixpkgs.follows` を外さない。外すと、アドオンのビルドに使った fcitx5 と実行する fcitx5 のバージョンがずれる
- home-manager の `gtk.enable` を有効にしていると、fcitx5 module は GTK の settings.ini に `gtk-im-module=fcitx` を書く。
  GTK アプリは Wayland の text-input でなく fcitx の GTK モジュールを使うので、ディストリの GTK アプリにはディストリの fcitx5-gtk が要る
- (症状が出たときだけ対処する) home-manager の `fcitx5-daemon` が Wayland のソケットより先に起動すると、
  `journalctl --user -u fcitx5-daemon` に `Failed to open wayland connection` が出て、fcitx5 は動いているのに入力できない。
  ソケットを待ってから起動させる (`wayland-0` は実際のソケット名に合わせる):
  `systemd.user.services.fcitx5-daemon.Service.ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 50); do [ -S \"$XDG_RUNTIME_DIR/wayland-0\" ] && exit 0; sleep 0.1; done; exit 1'";`
- KDE Plasma のシステム設定 →「仮想キーボード」で別の IME を選び直すと、home-manager module が書いた kwinrc の設定が上書きされる

## 確認

Meltype に切り替えて変換できるかは、ユーザーに GUI アプリで打ってもらって確かめる。

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

アドオンが読み込まれていなければ、`journalctl --user -u fcitx5-daemon` か、`fcitx5 -r --verbose '*=5'` を端末から起動して、
アドオン読み込み時のエラーを見る。

### IBus

```sh
# ibus コマンドは WAYLAND_DISPLAY (X11 では DISPLAY) から接続先を決める。GUI セッション外のシェル (SSH など) では
# GUI セッションと同じ値 (例: wayland-0) を設定しないと "Can't connect to IBus" になる

# ibus-daemon が Meltype の component を読み込んでいるか。meltype が出る
ibus list-engine | grep -w meltype

# (home-manager module) ibus-daemon に IBUS_COMPONENT_PATH と --cache=refresh が渡っているか
pid=$(systemctl --user show -p MainPID --value org.freedesktop.IBus.session.GNOME.service)
tr '\0' '\n' < /proc/$pid/environ | grep IBUS_COMPONENT_PATH
tr '\0' ' ' < /proc/$pid/cmdline

# Meltype に切り替えた後、エンジンのプロセスが /nix/store のラッパーから起動しているか
pgrep -af ibus-engine-meltype
```

## 実行時のデータ

設定と学習データは `~/.local/share/Meltype`。Nix の管理外なので、パッケージを消しても残る。
