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
      release = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.meltype-src;
      releaseVersion =
        let
          m = builtins.match "v(.+)" (release.original.ref or "");
        in
        if m == null then
          throw "flake.nix の meltype-src の URL は github:yksr-melt/Meltype/v<版> の形でリリースタグを指す"
        else
          builtins.head m;
      releaseSrc = builtins.fetchTree release.locked;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          meltype-bin = pkgs.callPackage ./packages/meltype-bin {
            version = releaseVersion;
            repoSrc = releaseSrc;
          };
          meltype = pkgs.callPackage ./packages/meltype {
            inherit meltype-bin;
            src = meltype-src;
            version =
              if meltype-src.narHash == release.locked.narHash then
                releaseVersion
              else
                "0-unstable-${builtins.substring 0 8 meltype-src.lastModifiedDate}-${meltype-src.shortRev}";
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
