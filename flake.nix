{
  description = "Meltype (Japanese input method) packaged for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    # 検証用の *-unstable が使う upstream のソース。`nix flake update meltype-src` で main の HEAD に更新する
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
      # upstream のリリース zip は x86_64 だけ
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = rec {
        meltype = pkgs.callPackage ./packages/meltype { };
        fcitx5-meltype = pkgs.callPackage ./packages/fcitx5-meltype { inherit meltype; };
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
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
