# nix-meltype のメンテナンス

リリース版の更新は、`packages/meltype/default.nix` の `version` と `passthru.repoSrc` の `hash`、`packages/meltype/sources.nix` の CPU ごとの zip の `hash` を書き換える
(`fcitx5-meltype` / `ibus-meltype` は `meltype.repoSrc` のソースを使う)。
利用者向けの導入手順は `INSTALL.md` (README のプロンプトが raw URL で読ませる)。パッケージや手順を変えたらそちらも直す。
ディストリのデスクトップと噛み合わせる処理はコードで表せるものを home-manager module (`modules/home-manager.nix`) に入れ、
INSTALL.md には軸 (fcitx5・IBus と desktop) ごとの選び方と、ユーザーの状態を書き換える作業だけを書く。組み合わせごとの手順を INSTALL.md に足さない。
module は `tests/` の flake が fcitx5・IBus × desktop の組み合わせごとに評価する (`nix flake check ./tests`、CI では最新の home-manager で)。
aarch64 のビルドとテストは手元でできないので、CI (`.github/workflows/build.yml`) の `ubuntu-24.04-arm` のジョブで確かめる。
`nix build .#fcitx5-meltype` で upstream のテスト (fcitx5 の testfrontend でキー入力と確定文字列を確かめる) が走る。
`nix build .#ibus-meltype` では upstream の IBus 向けテスト (Mozc 込みの変換) と、専用の ibus-daemon に component を読ませて
かなが出るかの確認 (`packages/ibus-meltype/check-component.py`) が走る。

検証用の `*-unstable` は CI (`.github/workflows/update-unstable.yml`) が毎日 `nix flake update meltype-src` で
upstream main の HEAD に更新し、`fcitx5-meltype-unstable` と `ibus-meltype-unstable` のビルドが x86_64 と aarch64 の両方で通ったときだけ main に push する。
特定のコミットを試すときは `--override-input meltype-src github:yksr-melt/Meltype/<rev>` を付けてビルドする。
HEAD の本体とリリース版の Mozc ヘルパーの組み合わせは、IBus 版のテストだけが検証する (fcitx5 版のテストは Mozc 無しで走る)。

