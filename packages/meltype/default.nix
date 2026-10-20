# Meltype の本体 (libMeltypeNative.so) を upstream のソース (flake input meltype-src) から NativeAOT でビルドする。
# Mozc の変換ヘルパーは meltype-bin (リリース版) のビルド済みバイナリを使う。meltype-src を main のコミットに差し替えたときも
# ヘルパーはリリース版のままになる。upstream の bot.yml も HEAD の本体と最新リリースのヘルパーを組み合わせている。
# csproj に PackageReference が無く、NativeAOT のコンパイラは nixpkgs の .NET SDK に同梱されるので、nugetDeps は要らない。
{
  lib,
  stdenv,
  buildDotnetModule,
  dotnetCorePackages,
  patchelf,
  clang,
  icu,
  zlib,
  meltype-bin,
  src,
  version,
}:
let
  # upstream の linux/build.sh と同じ publish の引数
  dotnetFlags = [
    "-p:PublishAot=true"
    "-p:NativeLib=Shared"
    "-p:StripSymbols=true"
  ];
in
buildDotnetModule {
  pname = "meltype";
  inherit src version;

  projectFile = "src/Meltype.Mac.Native/Meltype.Mac.Native.csproj";
  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  selfContainedBuild = true;
  # restore にも同じ引数を渡す (PublishAot=true で ILCompiler のパッケージが要ると判定される)
  inherit dotnetFlags;

  # NativeAOT のリンクに使う (upstream の linux/build.sh と同じ clang)
  nativeBuildInputs = [
    clang
    patchelf
  ];
  buildInputs = [ zlib ];

  # NativeAOT の共有ライブラリは publish でしか作られないので、buildDotnetModule の build/install を使わずに publish する。
  # フラグはシェル変数 $dotnetFlags から取らない (__structuredAttrs の有無で文字列か配列かが変わる)
  buildPhase = ''
    runHook preBuild
    dotnet publish src/Meltype.Mac.Native/Meltype.Mac.Native.csproj -c Release -r ${dotnetCorePackages.systemToDotnetRid stdenv.hostPlatform.system} --no-restore ${lib.escapeShellArgs dotnetFlags} -o publish
    runHook postBuild
  '';

  # 配置は meltype-bin と同じ。fcitx5-meltype / ibus-meltype は repoSrc と lib/meltype だけを参照する
  installPhase = ''
    runHook preInstall
    install -Dm755 publish/MeltypeNative.so $out/lib/meltype/libMeltypeNative.so
    install -Dm644 linux/icon.png $out/lib/meltype/icon.png
    ln -s ${meltype-bin}/lib/meltype/mozc $out/lib/meltype/mozc
    runHook postInstall
  '';

  # ICU を dlopen するので RUNPATH に足す。理由は meltype-bin の postFixup と同じ
  postFixup = ''
    patchelf --add-rpath ${lib.getLib icu}/lib $out/lib/meltype/libMeltypeNative.so
  '';

  passthru.repoSrc = src;

  meta = meltype-bin.meta // {
    description = "Meltype core library built from source, with the prebuilt Mozc helper";
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryNativeCode # Mozc ヘルパー
    ];
  };
}
