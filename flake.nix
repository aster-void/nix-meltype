{
  description = "Meltype (Japanese input method) packaged for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    # 検証用の *-unstable が使う upstream のソース。CI (.github/workflows/update-unstable.yml) が毎日 main の HEAD に更新する
    meltype-src = {
      url = "github:yksr-melt/Meltype";
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
      forAllSystems = nixpkgs.lib.genAttrs (builtins.attrNames (import ./packages/meltype/sources.nix));
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
        meltype = pkgs.callPackage ./packages/meltype { };
        fcitx5-meltype = pkgs.callPackage ./packages/fcitx5-meltype { inherit meltype; };
        ibus-meltype = pkgs.callPackage ./packages/ibus-meltype { inherit meltype; };
        default = fcitx5-meltype;

        meltype-unstable = pkgs.callPackage ./packages/meltype-unstable {
          inherit meltype;
          src = meltype-src;
          version = "0-unstable-${
            builtins.substring 0 8 meltype-src.lastModifiedDate
          }-${meltype-src.shortRev}";
        };
        fcitx5-meltype-unstable = pkgs.callPackage ./packages/fcitx5-meltype {
          meltype = meltype-unstable;
        };
        ibus-meltype-unstable = pkgs.callPackage ./packages/ibus-meltype {
          meltype = meltype-unstable;
        };
      }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
