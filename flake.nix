{
  description = "Meltype (Japanese input method) packaged for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    # meltype (本体) をビルドする upstream のソース。デフォルトはリリースタグで、meltype-bin の版もこのタグから決まる。
    # 利用者は inputs.nix-meltype.inputs.meltype-src.url で pre 版のタグや main のコミットに差し替える
    meltype-src = {
      url = "github:yksr-melt/Meltype/v1.3.0";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      meltype-src,
    }:
    let
      # 対応システムは、upstream がリリース zip を出しているもの
      forAllSystems = nixpkgs.lib.genAttrs (
        builtins.attrNames (import ./packages/meltype-bin/sources.nix)
      );
      # meltype-src のデフォルト。利用者が meltype-src を差し替えても、このリポジトリの flake.lock は変わらない
      releaseSrc = builtins.fetchTree (builtins.fromJSON (builtins.readFile ./flake.lock))
        .nodes.meltype-src.locked;
      # upstream のリリース bot はタグを打つときに csproj の Version をその版にする (v1.2.2-pre.2 以降)。
      # main のコミットでは、直前のタグの版になる
      versionOf =
        src:
        let
          m = builtins.match ".*<Version>([^<]+)</Version>.*" (
            builtins.readFile "${src}/src/Meltype.Core/Meltype.Core.csproj"
          );
        in
        if m == null then
          throw "${src}/src/Meltype.Core/Meltype.Core.csproj に <Version> が無い"
        else
          builtins.head m;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          meltype-bin = pkgs.callPackage ./packages/meltype-bin {
            version = versionOf releaseSrc;
            repoSrc = releaseSrc;
          };
          meltype = pkgs.callPackage ./packages/meltype {
            inherit meltype-bin;
            src = meltype-src;
            version = versionOf meltype-src;
          };
          fcitx5-meltype = pkgs.callPackage ./packages/fcitx5-meltype { inherit meltype; };
          ibus-meltype = pkgs.callPackage ./packages/ibus-meltype { inherit meltype; };
          default = fcitx5-meltype;
        }
      );

      homeModules.default = import ./modules/home-manager.nix self;

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
