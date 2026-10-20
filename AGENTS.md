# nix-meltype のメンテナンス

リリース版の更新は、`flake.nix` の `meltype-src` の URL のタグと、`packages/meltype-bin/default.nix` の `version` と `passthru.repoSrc` の `hash`、
`packages/meltype-bin/sources.nix` の CPU ごとの zip の `hash` を書き換えて、`nix flake update meltype-src` する。
`meltype-src` と `meltype-bin` のタグがずれていると `nix flake check` が失敗する。
本体 (`meltype`) は `meltype-src` からビルドし、Mozc ヘルパーだけ `meltype-bin` から取る。`fcitx5-meltype` / `ibus-meltype` は `meltype.repoSrc` (= `meltype-src`) のソースを使う。
利用者向けの導入手順は `INSTALL.md` (README のプロンプトが raw URL で読ませる)。パッケージや手順を変えたらそちらも直す。
ディストリのデスクトップと噛み合わせる処理はコードで表せるものを home-manager module (`modules/home-manager.nix`) に入れ、
INSTALL.md には軸 (fcitx5・IBus と desktopWorkaround) ごとの選び方と、ユーザーの状態を書き換える作業だけを書く。組み合わせごとの手順を INSTALL.md に足さない。
module は `tests/` の flake が fcitx5・IBus × desktopWorkaround の組み合わせごとに評価する (`nix flake check ./tests`、CI では最新の home-manager で)。
aarch64 のビルドとテストは手元でできないので、CI (`.github/workflows/build.yml`) の `ubuntu-24.04-arm` のジョブで確かめる。
`nix build .#fcitx5-meltype` で upstream のテスト (fcitx5 の testfrontend でキー入力と確定文字列を確かめる) が走る。
`nix build .#ibus-meltype` では upstream の IBus 向けテスト (Mozc 込みの変換) と、専用の ibus-daemon に component を読ませて
かなが出るかの確認 (`packages/ibus-meltype/check-component.py`) が走る。

利用者は `meltype-src` を pre 版のタグや main のコミットに差し替えて使う (README)。この flake は main を追わない。
CI (`.github/workflows/upstream-main.yml`) が毎日 `--override-input meltype-src github:yksr-melt/Meltype` で upstream main の HEAD をビルドし、
upstream の変更でビルドが通らなくなったことを検出する (lock は更新しない)。
特定のコミットを試すときも `--override-input meltype-src github:yksr-melt/Meltype/<rev>` を付けてビルドする。
差し替えた本体とリリース版の Mozc ヘルパーの組み合わせは、IBus 版のテストだけが検証する (fcitx5 版のテストは Mozc 無しで走る)。

