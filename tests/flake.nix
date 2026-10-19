# home-manager module を、使える fcitx5・IBus × desktop の組み合わせすべてで評価する。
# home-manager を本体の flake の input にすると利用者の lock にも入るので、テストは別の flake に分ける
{
  inputs = {
    nix-meltype.url = "path:..";
    nixpkgs.follows = "nix-meltype/nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nix-meltype,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      lib = nixpkgs.lib;
      fcitx5 = {
        i18n.inputMethod = {
          enable = true;
          type = "fcitx5";
          fcitx5.waylandFrontend = true;
        };
      };
      # 各組み合わせの home-manager の設定 (programs.meltype.enable 以外)
      combinations = [
        (fcitx5 // { programs.meltype.framework.fcitx5.desktop = "gnome"; })
        (fcitx5 // { programs.meltype.framework.fcitx5.desktop = "plasma"; })
        (fcitx5 // { programs.meltype.framework.fcitx5.desktop = "other"; })
        { programs.meltype.framework.gnomeIbus = { }; }
      ];
      home =
        system: settings:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            nix-meltype.homeModules.default
            settings
            {
              home = {
                username = "test";
                homeDirectory = "/home/test";
                stateVersion = "25.05";
              };
              programs.meltype.enable = true;
            }
          ];
        };
    in
    {
      # 評価だけを確かめる (パッケージのビルドは本体の CI がする)。drvPath の context を落として、ビルドの依存にしない
      checks = lib.genAttrs (builtins.attrNames nix-meltype.packages) (system: {
        eval = nixpkgs.legacyPackages.${system}.writeText "meltype-home-manager-eval" (
          lib.concatMapStringsSep "\n" (
            c: builtins.unsafeDiscardStringContext (home system c).activationPackage.drvPath
          ) combinations
        );
      });
    };
}
