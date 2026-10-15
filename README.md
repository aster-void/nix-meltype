# nix-meltype

[Meltype](https://github.com/yksr-melt/Meltype) の fcitx5 アドオンを Nix で入れるための flake。

- `packages.x86_64-linux.meltype` — 本体 (`libMeltypeNative.so`) と Mozc 変換ヘルパー。リリース zip のビルド済みバイナリを使う
- `packages.x86_64-linux.fcitx5-meltype` (`default`) — fcitx5 アドオン。nixpkgs の fcitx5 に対してソースからビルドする

IBus エンジンはパッケージ化していない。ibus-daemon はユーザーディレクトリのコンポーネントを読まないため、
non-NixOS の home-manager から登録する手段がない。

## home-manager

```nix
# flake.nix
inputs.nix-meltype = {
  url = "github:aster-void/nix-meltype";
  inputs.nixpkgs.follows = "nixpkgs";
};

# module
i18n.inputMethod.fcitx5.addons = [ inputs.nix-meltype.packages.${pkgs.system}.default ];
```

設定と学習データは `~/.local/share/Meltype`。
