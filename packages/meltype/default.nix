# Meltype の本体 (libMeltypeNative.so, .NET NativeAOT) と Mozc の変換ヘルパー。リリース zip のビルド済みバイナリを使う。
# ソースからのビルドは .NET 10 の NativeAOT と Mozc の Bazel ビルド (upstream CI で 30〜40 分) が要るので採らない。
# zip 内の fcitx5/meltype.so は Ubuntu 24.04 の fcitx5 向けなので使わず、fcitx5-meltype でソースからビルドする。
# 更新は version と、src・repoSrc の hash を書き換える。
{
  lib,
  stdenvNoCC,
  fetchurl,
  fetchFromGitHub,
  autoPatchelfHook,
  patchelf,
  unzip,
  icu,
  stdenv,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "meltype";
  version = "1.3.0";

  src = fetchurl {
    url = "https://github.com/yksr-melt/Meltype/releases/download/v${finalAttrs.version}/Meltype-${finalAttrs.version}-linux.zip";
    hash = "sha256-KE7lcpl13y3p7U/X1fWyKwmC23xaTyGGuwHVusg15zY=";
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

  # fcitx5-meltype がビルドするソース。本体と同じタグ
  passthru.repoSrc = fetchFromGitHub {
    owner = "yksr-melt";
    repo = "Meltype";
    tag = "v${finalAttrs.version}";
    hash = "sha256-WihlGZQCejXSdhRQD7WJQnamwrxmjqLNecop7mDlk9s=";
  };

  meta = {
    description = "Meltype core library and Mozc conversion helper (prebuilt)";
    homepage = "https://github.com/yksr-melt/Meltype";
    license = with lib.licenses; [
      gpl3Plus
      bsd3 # Mozc
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
})
