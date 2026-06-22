# BearBrowser — SourceOS privacy / anti-fingerprinting browser.
#
# Packages the prebuilt Linux Gecko build (compiled with the BearBrowser engine
# anti-fingerprint patches: canvas text-metric quantization + audio farble in
# libxul) from the BearBrowser GitHub release. This is a prebuilt-binary wrapper
# (firefox-bin style) — autoPatchelf + the Gecko runtime libs + a desktop entry.
#
# NOTE: built from the v0.1.0-alpha "human-secure" Linux artifact. When a new
# release is cut, bump `version` + `src.url` + `src.hash`.
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, wrapGAppsHook3
, gtk3
, glib
, dbus-glib
, libXt
, alsa-lib
, libX11
, libXcursor
, libXdamage
, libXrandr
, libXcomposite
, libXext
, libXfixes
, libXrender
, libXtst
, libXScrnSaver
, nspr
, nss
, pango
, atk
, cairo
, gdk-pixbuf
, freetype
, fontconfig
, libxcb
, mesa
, pciutils
, ffmpeg
, libnotify
, gnome2 ? null
}:

stdenv.mkDerivation rec {
  pname = "bearbrowser";
  version = "0.1.0-alpha";

  src = fetchurl {
    url = "https://github.com/SourceOS-Linux/BearBrowser/releases/download/v${version}/bearbrowser-${version}-linux-x86_64.tar.gz";
    hash = "sha256-K17S8uORD1RDL7OLPyU2LkxcXgo5fTBGIRJ+Nd/gNRA=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper wrapGAppsHook3 ];

  # Gecko runtime libraries (autoPatchelf resolves the binary's NEEDED libs here).
  buildInputs = [
    stdenv.cc.cc        # libstdc++ / libgcc_s
    gtk3 glib dbus-glib libXt alsa-lib
    libX11 libXcursor libXdamage libXrandr libXcomposite libXext libXfixes
    libXrender libXtst libXScrnSaver
    nspr nss pango atk cairo gdk-pixbuf freetype fontconfig libxcb mesa
    pciutils ffmpeg libnotify
  ];

  # The release tarball is a dist/bin tree rooted at ./bin/.
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Stage the Gecko dist under libexec, expose a wrapped launcher on PATH.
    mkdir -p "$out/libexec/bearbrowser" "$out/bin" "$out/share/applications" "$out/share/pixmaps"
    cp -r bin/* "$out/libexec/bearbrowser/"

    # The executable is named "bearbrowser" (--with-app-name=bearbrowser).
    makeWrapper "$out/libexec/bearbrowser/bearbrowser" "$out/bin/bearbrowser" \
      --prefix LD_LIBRARY_PATH : "$out/libexec/bearbrowser" \
      --set MOZ_LEGACY_PROFILES 1 \
      --set MOZ_ALLOW_DOWNGRADE 1

    # Icon (fall back silently if the dist layout differs).
    if [ -f "$out/libexec/bearbrowser/browser/chrome/icons/default/default128.png" ]; then
      cp "$out/libexec/bearbrowser/browser/chrome/icons/default/default128.png" \
         "$out/share/pixmaps/bearbrowser.png" || true
    fi

    cat > "$out/share/applications/bearbrowser.desktop" <<EOF
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=BearBrowser
    GenericName=Web Browser
    Comment=SourceOS privacy / anti-fingerprinting browser
    Exec=$out/bin/bearbrowser %U
    Icon=bearbrowser
    Terminal=false
    Categories=Network;WebBrowser;
    MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
    StartupNotify=true
    StartupWMClass=bearbrowser
    EOF

    runHook postInstall
  '';

  meta = {
    description = "SourceOS privacy / anti-fingerprinting browser (Gecko + engine anti-fp patches)";
    homepage = "https://github.com/SourceOS-Linux/BearBrowser";
    license = lib.licenses.mpl20;   # LibreWolf/Firefox base — MPL-2.0
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "bearbrowser";
  };
}
