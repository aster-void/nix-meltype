{
  description = "Meltype (Japanese input method) packaged for Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";

  outputs =
    { self, nixpkgs }:
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
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
