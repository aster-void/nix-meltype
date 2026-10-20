# Meltype の本体 (libMeltypeNative.so, .NET NativeAOT) と Mozc の変換ヘルパー。リリース zip のビルド済みバイナリを使う。
# meltype (ソースビルドの本体) は、ここから Mozc ヘルパーだけを使う。ヘルパーのソースビルドは Mozc の Bazel ビルド
# (upstream CI で 30〜40 分) が要るので採らない。
# zip 内の fcitx5/meltype.so は Ubuntu 24.04 の fcitx5 向けなので使わず、fcitx5-meltype でソースからビルドする。
# version と repoSrc は flake.nix が flake input meltype-src のデフォルト (自分の flake.lock) から渡す。
{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  patchelf,
  unzip,
  icu,
  stdenv,
  version,
  repoSrc,
}:
let
  sources = import ./sources.nix;
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "meltype-bin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/yksr-melt/Meltype/releases/download/v${finalAttrs.version}/Meltype-${finalAttrs.version}-${source.asset}.zip";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    patchelf
    unzip
  ];
  # meltype_mozc_helper の libstdc++ / libgcc_s
  buildInputs = [ stdenv.cc.cc.lib ];

  # 配置はアドオンが読むパス (MELTYPE_DIR/libMeltypeNative.so, MELTYPE_DIR/mozc/meltype_mozc_helper) に合わせる
  installPhase = ''
    runHook preInstall
    install -Dm755 libMeltypeNative.so $out/lib/meltype/libMeltypeNative.so
    install -Dm755 mozc/meltype_mozc_helper $out/lib/meltype/mozc/meltype_mozc_helper
    install -Dm644 icon.png $out/lib/meltype/icon.png
    runHook postInstall
  '';

  # libMeltypeNative.so は InvariantGlobalization=false なので、起動時に libicuuc.so.<ver> を dlopen する。
  # NEEDED に無いため runtimeDependencies では RUNPATH に入らず、fixupPhase の shrink-rpath でも消される。
  # shrink-rpath の後に走る postFixup で足す
  postFixup = ''
    patchelf --add-rpath ${lib.getLib icu}/lib $out/lib/meltype/libMeltypeNative.so
  '';

  # fcitx5-meltype / ibus-meltype に meltype-bin を渡したときのソース。本体と同じタグ
  passthru = { inherit repoSrc; };

  meta = {
    description = "Meltype core library and Mozc conversion helper (prebuilt)";
    homepage = "https://github.com/yksr-melt/Meltype";
    license = with lib.licenses; [
      gpl3Plus
      bsd3 # Mozc
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
  };
})
