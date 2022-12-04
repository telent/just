{ stdenv
, callPackage
, copyDesktopItems
, fennel
, fetchFromGitHub
, fetchurl
, glib-networking
, gobject-introspection
, gtk3
, gnome3
, lib
, librsvg
, lua53Packages
, lua5_3
, makeDesktopItem
, makeWrapper
, webkitgtk
, writeText
}:
let pname = "just";
    lua = lua5_3.withPackages (ps: with ps; [
      inspect
      lgi
      luafilesystem
      luaposix
      readline
    ]);
    fennel_ = fennel.override { inherit lua; };
    glib_networking_gio  = "${glib-networking}/lib/gio/modules";
in stdenv.mkDerivation rec {
  inherit pname;
  fennel = fennel_;

  version = "0.1";
  src =./.;

  GIO_EXTRA_MODULES = glib_networking_gio;

  buildInputs = [ lua gtk3 webkitgtk gobject-introspection.dev
                  fennel
                  glib-networking  ];
  nativeBuildInputs = [ lua makeWrapper copyDesktopItems ];

  makeFlags = [ "PREFIX=${placeholder "out"}" ];

  desktopItems = [
    (makeDesktopItem rec {
      desktopName = "Just Browsing";
      name = pname;
      exec = pname;
      categories = ["Network"] ;
      icon = ./just.png;
      genericName = "Web browser";
    })
  ];

  postInstall = ''
    makeWrapper ${fennel}/bin/fennel \
      $out/bin/${pname} \
      --set GI_TYPELIB_PATH "$GI_TYPELIB_PATH" \
      --prefix GIO_EXTRA_MODULES ":" "${glib_networking_gio}" \
      --add-flags "--add-fennel-path $out/lib/just/?.fnl" \
      --add-flags "--add-package-path $out/lib/just/?.lua" \
      --add-flags "$out/lib/just/just.fnl"
  '';
}
