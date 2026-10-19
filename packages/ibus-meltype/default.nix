# Meltype の IBus エンジン。upstream の ibus-engine-meltype (Python) を、本体 (meltype) と同じディレクトリに並べて置く。
# ソースは本体と同じコミットを使う (meltype.repoSrc)。
{
  lib,
  stdenv,
  makeWrapper,
  wrapGAppsNoGuiHook,
  gobject-introspection,
  python3,
  ibus,
  xdg-utils,
  dbus,
  meltype,
}:
let
  python = python3.withPackages (ps: [ ps.pygobject3 ]);
  # IBus の GI overrides (gi/overrides/IBus.py)。エンジンが使う IBus.Property(type=...) などはこれが無いと TypeError になる
  ibusOverrides = "${ibus}/${python3.sitePackages}";
in
stdenv.mkDerivation {
  pname = "ibus-meltype";
  inherit (meltype) version;

  src = meltype.repoSrc;

  nativeBuildInputs = [
    makeWrapper
    wrapGAppsNoGuiHook
    gobject-introspection
  ];
  # IBus の typelib を gappsWrapperArgs の GI_TYPELIB_PATH に入れる
  buildInputs = [ ibus ];

  dontConfigure = true;
  dontBuild = true;
  dontWrapGApps = true;

  # エンジンは自分の realpath のディレクトリから libMeltypeNative.so・mozc/meltype_mozc_helper・meltype.xml を読む。
  # upstream のテストも同じディレクトリのスクリプトを python で直接読み込むので、スクリプトはここでは書き換えず、
  # 起動用のラッパーを libexec に別に作る (wrapProgram でスクリプトを包むと、テストが読むファイルがシェルスクリプトになる)
  installPhase = ''
    runHook preInstall
    dir=$out/lib/ibus-meltype
    install -Dm755 linux/ibus-engine-meltype $dir/ibus-engine-meltype
    ln -s ${meltype}/lib/meltype/libMeltypeNative.so ${meltype}/lib/meltype/mozc ${meltype}/lib/meltype/icon.png $dir/
    substitute linux/meltype.xml $dir/meltype.xml --replace-fail @DIR@ $dir
    # <exec> だけ libexec のラッパーに向ける。<icon> は $dir/icon.png のまま
    mkdir -p $out/share/ibus/component
    substitute $dir/meltype.xml $out/share/ibus/component/meltype.xml \
      --replace-fail "$dir/ibus-engine-meltype" "$out/libexec/ibus-engine-meltype"
    runHook postInstall
  '';

  # xdg-open は不具合報告のメニューで使う。ユーザー環境の xdg-open を優先するので suffix
  postFixup = ''
    makeWrapper ${python.interpreter} $out/libexec/ibus-engine-meltype \
      "''${gappsWrapperArgs[@]}" \
      --prefix PYTHONPATH : ${ibusOverrides} \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --add-flags $out/lib/ibus-meltype/ibus-engine-meltype
  '';

  # upstream CI (.github/workflows/linux.yml) のテストのうち、test_virtual_key と test_integration (実際の Mozc ヘルパーで変換) を回す。
  # test_daemon は nixpkgs の ibus (1.5.31 以降) では通らないので、代わりに check-component.py で component とラッパーを確かめる (理由はその冒頭)
  doInstallCheck = true;
  nativeInstallCheckInputs = [
    python
    ibus
    dbus
  ];
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$TMPDIR
    export PYTHONPATH=${ibusOverrides}
    export GI_TYPELIB_PATH=${lib.getLib ibus}/lib/girepository-1.0''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}
    python3 linux/tests/test_virtual_key.py
    timeout 120 python3 linux/tests/test_integration.py $out/lib/ibus-meltype

    export XDG_RUNTIME_DIR=$TMPDIR/runtime XDG_CONFIG_HOME=$TMPDIR/config XDG_CACHE_HOME=$TMPDIR/cache MELTYPE_DATA_DIR=$TMPDIR/meltype
    mkdir -p $XDG_RUNTIME_DIR $XDG_CONFIG_HOME $XDG_CACHE_HOME $MELTYPE_DATA_DIR
    export IBUS_ADDRESS=unix:path=$TMPDIR/ibus.socket IBUS_COMPONENT_PATH=$out/share/ibus/component
    timeout 60 dbus-run-session --config-file=${dbus}/share/dbus-1/session.conf -- bash -c '
      ibus-daemon -s -p disable -c disable -E disable -a "$IBUS_ADDRESS" --cache=none &
      for _ in $(seq 50); do if [ -S "$TMPDIR/ibus.socket" ]; then break; fi; sleep 0.1; done
      python3 ${./check-component.py}; status=$?
      kill $!
      exit $status'
    runHook postInstallCheck
  '';

  meta = {
    description = "Japanese input method that keeps English words as-is without toggling Hankaku/Zenkaku (IBus engine)";
    homepage = "https://github.com/yksr-melt/Meltype";
    license = lib.licenses.gpl3Plus;
    # NixOS の i18n.inputMethod.ibus.engines はこれが無いパッケージを型検査で弾く
    isIbusEngine = true;
    inherit (meltype.meta) platforms;
  };
}
