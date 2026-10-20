# Meltype を home-manager で入れる module。i18n.inputMethod の enable / type はユーザーが書き、この module は
# Meltype のアドオンを足す処理と、ディストリのデスクトップと nixpkgs の IME を噛み合わせる処理だけを持つ。
# 噛み合わせの処理は home-manager の fcitx5 module 自体の不足なので、home-manager 側で直ったらここから消す。
# オプションには環境の事実とユーザーの選択だけを置き、どの処理をするかは module が決める
# (個別の処理を外したいユーザーは、module が設定した home-manager のオプションを直接上書きする)。
# fcitx5 側の処理は NixOS 上の home-manager でも害が無いので、non-NixOS かどうかで分けない。
# NixOS の判定には submoduleSupport.enable (NixOS の module として使う home-manager で true) を使う。standalone の home-manager を
# NixOS で使う場合は判定できない (targets.genericLinux.enable を使う案は、有効にすると GPU ドライバのセットアップまで求められるので採らない)。
# packagesFor は flake.nix の、pkgs からこの flake のパッケージを作る関数
packagesFor:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.meltype;
  im = config.i18n.inputMethod;
  packages = packagesFor pkgs;
  fcitx5 = cfg.framework.fcitx5 or null;
  gnomeIbus = cfg.framework.gnomeIbus or null;
  # GNOME が ibus-daemon を起動する systemd user unit
  gnomeIbusUnit = "org.freedesktop.IBus.session.GNOME.service";
  packageOption =
    name: description:
    lib.mkOption {
      type = lib.types.package;
      default = packages.${name};
      defaultText = lib.literalExpression "(pkgs に overlays.default を当てたもの).${name}";
      inherit description;
    };
in
{
  options.programs.meltype = {
    enable = lib.mkEnableOption "Meltype";
    # fcitx5 と gnomeIbus はどちらか一方だけを選ぶので、attrTag (キーをちょうど1つ持つ attrset) で表す
    framework = lib.mkOption {
      description = "Meltype を載せる入力メソッドフレームワーク。";
      type = lib.types.attrTag {
        fcitx5 = lib.mkOption {
          description = ''
            nixpkgs の fcitx5 のアドオンとして足す。i18n.inputMethod の enable と type = "fcitx5" はユーザーが書く。
          '';
          type = lib.types.submodule {
            options = {
              # 既定値を置かない。Plasma で書き忘れると、エラーにならずに入力できなくなる
              desktopWorkaround = lib.mkOption {
                type = lib.types.enum [
                  "gnome"
                  "plasma"
                  "none"
                ];
                description = "ログインするデスクトップ環境に合わせて入れる workaround。該当するデスクトップが無ければ none。";
              };
              package = packageOption "fcitx5-meltype" "fcitx5 アドオン。";
            };
          };
        };
        gnomeIbus = lib.mkOption {
          description = ''
            non-NixOS の GNOME で、ディストリの ibus-daemon (/usr/bin/ibus-daemon) に足す。
            home-manager には IBus の i18n.inputMethod.type が無いので、i18n.inputMethod は設定しない。
          '';
          type = lib.types.submodule {
            options.package = packageOption "ibus-meltype" "IBus エンジン。";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = fcitx5 != null -> im.enable && im.type == "fcitx5";
            message = ''programs.meltype.framework.fcitx5 は i18n.inputMethod.enable = true と type = "fcitx5" を前提にする'';
          }
          {
            assertion = gnomeIbus != null -> !(im.enable && im.type == "fcitx5");
            message = "programs.meltype.framework.gnomeIbus は、i18n.inputMethod の fcitx5 を有効にしたままでは使えない";
          }
        ];
      }

      (lib.mkIf (fcitx5 != null) {
        i18n.inputMethod.fcitx5.addons = [ fcitx5.package ];

        # fcitx5 module は XMODIFIERS などを home.sessionVariables (hm-session-vars.sh) にしか書かないので、
        # ログインシェルがこれを読まない限り GUI アプリに届かない。GDM と Plasma はどちらも ~/.config/environment.d を取り込む。
        # home.sessionVariables 全体は転記しない (値の型やシェル構文が environment.d で使えない変数が混ざる)。
        # QT_PLUGIN_PATH (nixpkgs の Qt プラグイン) も転記しない。ディストリの Qt アプリが別バージョンの Qt のプラグインを読みにいく
        systemd.user.sessionVariables = lib.getAttrs (lib.filter (n: config.home.sessionVariables ? ${n}) [
          "GTK_IM_MODULE"
          "QT_IM_MODULE"
          "XMODIFIERS"
          "SDL_IM_MODULE"
          "GLFW_IM_MODULE"
        ]) config.home.sessionVariables;
      })

      # GNOME Wayland の gnome-shell はアプリの入力を IBus の D-Bus 名 (org.freedesktop.IBus) へ送る。nixpkgs の fcitx5 は
      # IBus 互換のフロントエンドでこの名前を取るので、ディストリの ibus-daemon は毎回 kill されて unit が failed で残る。
      # unit を mask して起動させない。unit が無いシステムでは何も起きない
      (lib.mkIf (fcitx5 != null && fcitx5.desktopWorkaround == "gnome") {
        xdg.configFile."systemd/user/${gnomeIbusUnit}".text = "";
      })

      # KWin は Wayland の input method プロトコルを自分が起動したプロセスにしか渡さないので、
      # systemd user service (fcitx5-daemon) で起動した fcitx5 では入力できない。KWin に起動させる
      (lib.mkIf (fcitx5 != null && fcitx5.desktopWorkaround == "plasma") {
        i18n.inputMethod.fcitx5.systemd.enable = false;
        # kwinrc は KWin 自身も書き換えるので、xdg.configFile でファイルごと管理せずキー単位で書く。
        # システム設定の「仮想キーボード」で別の IME を選び直すと、KWin がこのキーを上書きする
        qt.kde.settings.kwinrc.Wayland.InputMethod =
          "${im.package}/share/applications/org.fcitx.Fcitx5.desktop";
      })

      # ディストリの ibus-daemon に、起動時に次の2つを渡す。
      # - IBUS_COMPONENT_PATH: 設定すると既定の /usr/share/ibus/component を置き換えるので、それも並べる
      # - --cache=refresh: 既定 (auto) の ibus-daemon は、システムのキャッシュ /var/cache/ibus/bus/registry が古くなっていなければ
      #   それだけを読み、IBUS_COMPONENT_PATH の中身と照合しない
      # ExecStart は IBus upstream の unit (ディストリはこれを bindir=/usr/bin で入れる) の行に --cache=refresh を足したもの。
      # upstream の unit が変わったら追従が要る
      (lib.mkIf (gnomeIbus != null) {
        xdg.configFile."systemd/user/${gnomeIbusUnit}.d/meltype.conf".text = ''
          [Service]
          Environment=IBUS_COMPONENT_PATH=/usr/share/ibus/component:${gnomeIbus.package}/share/ibus/component
          ExecStart=
          ExecStart=sh -c 'exec /usr/bin/ibus-daemon --panel disable --cache=refresh $([ "$XDG_SESSION_TYPE" = "x11" ] && echo "--xim")'
        '';
      })
    ]
  );
}
