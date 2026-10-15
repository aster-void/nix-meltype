# Meltype の fcitx5 アドオン。本体は dlopen で読むので、ビルド時のリンクには要らない。
# ソースは本体と同じコミットを使う (meltype.repoSrc)。
{
  lib,
  stdenv,
  cmake,
  fcitx5,
  meltype,
}:
stdenv.mkDerivation {
  pname = "fcitx5-meltype";
  inherit (meltype) version;

  src = meltype.repoSrc;
  sourceRoot = "source/linux/fcitx5";

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail /usr/share/fcitx5/addon/keyboard.conf ${fcitx5}/share/fcitx5/addon/keyboard.conf
  '';

  nativeBuildInputs = [ cmake ];
  buildInputs = [ fcitx5 ];

  cmakeFlags = [
    "-DMELTYPE_DIR=${meltype}/lib/meltype"
    (lib.cmakeBool "BUILD_TESTING" true)
  ];

  # upstream のテスト: fcitx5 の testfrontend でキーを送り、確定文字列と候補一覧を確かめる。
  # 期待値は Mozc 無し (かなのまま確定) が前提なので、upstream CI と同じく本体だけの MELTYPE_DIR を渡す。
  # 本体の ICU 読み込み (meltype の postFixup) はここで検証される
  doCheck = true;
  preCheck = ''
    export HOME=$TMPDIR
    export MELTYPE_DIR=$TMPDIR/meltype-nomozc
    mkdir -p $MELTYPE_DIR
    ln -s ${meltype}/lib/meltype/libMeltypeNative.so $MELTYPE_DIR/
  '';

  # upstream の install ルールは無い。配置は upstream の install.sh に合わせる
  installPhase = ''
    runHook preInstall
    install -Dm755 meltype.so $out/lib/fcitx5/meltype.so
    install -Dm644 ../meltype-addon.conf $out/share/fcitx5/addon/meltype.conf
    mkdir -p $out/share/fcitx5/inputmethod
    substitute ../meltype.conf $out/share/fcitx5/inputmethod/meltype.conf \
      --replace-fail @DIR@ ${meltype}/lib/meltype
    runHook postInstall
  '';

  meta = {
    description = "Japanese input method that keeps English words as-is without toggling Hankaku/Zenkaku (fcitx5 addon)";
    homepage = "https://github.com/yksr-melt/Meltype";
    license = lib.licenses.gpl3Plus;
    inherit (meltype.meta) platforms;
  };
}
