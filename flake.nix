{
  description = "Meltype (Japanese input method) packaged for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    # meltype (本体) をビルドする upstream のソース。デフォルトは meltype-bin と同じリリースタグ (checks が確かめる)。
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
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          meltype-bin = pkgs.callPackage ./packages/meltype-bin { };
          # input からはタグ名が読めないので、meltype-bin のタグと同じソースのときだけその版を名乗る
          isRelease = meltype-src.narHash == meltype-bin.repoSrc.outputHash;
        in
        rec {
          inherit meltype-bin;
          meltype = pkgs.callPackage ./packages/meltype {
            inherit meltype-bin;
            src = meltype-src;
            version =
              if isRelease then
                meltype-bin.version
              else
                "0-unstable-${builtins.substring 0 8 meltype-src.lastModifiedDate}-${meltype-src.shortRev}";
          };
          fcitx5-meltype = pkgs.callPackage ./packages/fcitx5-meltype { inherit meltype; };
          ibus-meltype = pkgs.callPackage ./packages/ibus-meltype { inherit meltype; };
          default = fcitx5-meltype;
        }
      );

      checks = forAllSystems (system: {
        # meltype-src のデフォルトと meltype-bin を同じリリースに揃え忘れていないか
        meltype-src-matches-bin =
          let
            bin = self.packages.${system}.meltype-bin;
          in
          assert nixpkgs.lib.assertMsg (
            meltype-src.narHash == bin.repoSrc.outputHash
          ) "flake input meltype-src が meltype-bin ${bin.version} のタグと違うソースを指している";
          nixpkgs.legacyPackages.${system}.emptyFile;
      });

      homeModules.default = import ./modules/home-manager.nix self;

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
