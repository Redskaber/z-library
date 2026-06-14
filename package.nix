{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, wrapGAppsHook3
, makeWrapper
# Electron runtime dependencies
, alsa-lib
, atk
, at-spi2-atk
, at-spi2-core
, cairo
, cups
, dbus
, expat
, gdk-pixbuf
, glib
, gtk3
, libdrm
, libnotify
, libuuid
, libxkbcommon
, libGL          # libEGL.so.1 , libGL.so.1
, mesa
, nspr
, nss
, pango
, systemd
# libx11
, libx11
, libxcb
, libXcomposite
, libXcursor
, libXdamage
, libXext
, libXfixes
, libXi
, libXrandr
, libXrender
, libXtst
}:

let
  sources = import ./sources.nix;
  inherit (stdenv.hostPlatform) system;
  source =
    sources.${system}
      or (throw "z-library: unsupported system ${system}, missing entry in sources.nix");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "z-library";
  version = source.version;

  src = fetchurl {
    url = source.url;
    sha256 = source.sha256;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libnotify
    libuuid
    libxkbcommon
    libGL
    mesa
    nspr
    nss
    pango
    systemd
    libx11
    libxcb
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # 1.（opt/Z-Library -> $out/share/z-library）
    mkdir -p $out/share/z-library
    if [ -d opt/Z-Library ]; then
      cp -av opt/Z-Library/* $out/share/z-library/
    fi

    # 2. desktop
    if [ -d usr/share/applications ]; then
      mkdir -p $out/share/applications
      cp -av usr/share/applications/* $out/share/applications/
    fi

    # 3. icons
    if [ -d usr/share/icons ]; then
      cp -av usr/share/icons $out/share/
    fi

    # 4. FIX:desktop.exec（先占位，后面再替换成最终的 wrapper）
    find $out/share/applications -name "*.desktop" -exec sed -i "s|Exec=.*|Exec=$out/bin/z-library %U|g" {} +

    # 5. find main exe（ps: $out/share/z-library/Z-Library）
    MAIN_BIN="$out/share/z-library/Z-Library"
    if [ ! -f "$MAIN_BIN" ]; then
      echo "ERROR: Main binary not found at $MAIN_BIN"
      exit 1
    fi

    # 6. create wrapper，(1. add lib path | 2.sandbox params)
    mkdir -p $out/bin
    makeWrapper "$MAIN_BIN" "$out/bin/z-library" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath finalAttrs.buildInputs}" \
      --add-flags "--no-sandbox" \
      --add-flags "--enable-features=UseOzonePlatform" \
      --add-flags "--ozone-platform-hint=auto"

    # 7. optional：user data path，set env path
    # --set DOT_QODER_PATH "$HOME/.z-library"

    runHook postInstall
  '';

  # autoPatchelf 会自动处理 ELF 依赖，如果某些库找不到可以忽略
  # autoPatchelfIgnoreMissingDeps = [ "libsome.so" ];

  meta = {
    description = "Z-Library desktop application – the world's largest ebook library";
    homepage = "https://z-lib.io/";
    downloadPage = "https://z-lib.io/desktop";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = [ "redskaber" ];
    mainProgram = "z-library";
  };
})
