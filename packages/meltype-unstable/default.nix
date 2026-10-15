# 検証用。Meltype の本体 (libMeltypeNative.so) を upstream のソース (flake input meltype-src) から NativeAOT でビルドする。
# Mozc の変換ヘルパーはリリース版 (meltype) のビルド済みバイナリを使う。upstream の bot.yml も HEAD の本体と最新リリースの
# ヘルパーを組み合わせている。ヘルパーのソースビルドは Mozc の Bazel ビルドが要るので採らない。
# csproj に PackageReference が無く、NativeAOT のコンパイラは nixpkgs の .NET SDK に同梱されるので、nugetDeps は要らない。
{
  lib,
  buildDotnetModule,
  dotnetCorePackages,
  patchelf,
  clang,
  icu,
  zlib,
  meltype,
  src,
  version,
}:
buildDotnetModule {
  pname = "meltype-unstable";
  inherit src version;

  projectFile = "src/Meltype.Mac.Native/Meltype.Mac.Native.csproj";
  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  selfContainedBuild = true;
  # upstream の linux/build.sh と同じ publish の引数
  dotnetFlags = [
    "-p:PublishAot=true"
    "-p:NativeLib=Shared"
    "-p:StripSymbols=true"
  ];

  # NativeAOT のリンクに使う (upstream の linux/build.sh と同じ clang)
  nativeBuildInputs = [
    clang
    patchelf
  ];
  buildInputs = [ zlib ];

  # NativeAOT の共有ライブラリは publish でしか作られないので、buildDotnetModule の build/install を使わずに publish する
  buildPhase = ''
    runHook preBuild
    dotnet publish src/Meltype.Mac.Native/Meltype.Mac.Native.csproj -c Release -r linux-x64 --no-restore $dotnetFlags -o publish
    runHook postBuild
  '';

  # 配置はリリース版 (packages/meltype) と同じ。fcitx5-meltype は repoSrc と lib/meltype だけを参照する
  installPhase = ''
    runHook preInstall
    install -Dm755 publish/MeltypeNative.so $out/lib/meltype/libMeltypeNative.so
    install -Dm644 linux/icon.png $out/lib/meltype/icon.png
    ln -s ${meltype}/lib/meltype/mozc $out/lib/meltype/mozc
    runHook postInstall
  '';

  # ICU を dlopen するので RUNPATH に足す。理由はリリース版 (packages/meltype) の postFixup と同じ
  postFixup = ''
    patchelf --add-rpath ${lib.getLib icu}/lib $out/lib/meltype/libMeltypeNative.so
  '';

  passthru.repoSrc = src;

  meta = meltype.meta // {
    description = "Meltype core library built from source, with the prebuilt Mozc helper";
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryNativeCode # Mozc ヘルパー
    ];
  };
}
