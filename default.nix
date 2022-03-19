{ stdenv
, callPackage
, copyDesktopItems
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
, writeText
}:
let pname = "just";
    fennel = fetchurl {
      name = "fennel.lua";
      url = "https://fennel-lang.org/downloads/fennel-1.0.0";
      hash = "sha256:1nha32yilzagfwrs44hc763jgwxd700kaik1is7x7lsjjvkgapw7";
    };
    webkitgtk = gnome3.webkitgtk;

    lua = lua5_3.withPackages (ps: with ps; [
      inspect
      lgi
      luafilesystem
      luaposix
      readline
    ]);
    glib_networking_gio  = "${glib-networking}/lib/gio/modules";
in stdenv.mkDerivation {
  inherit pname fennel;
  version = "0.1";
  src =./.;

  GIO_EXTRA_MODULES = glib_networking_gio;

  buildInputs = [ lua gtk3 webkitgtk gobject-introspection.dev
                  glib-networking  ];
  nativeBuildInputs = [ lua makeWrapper copyDesktopItems ];

  makeFlags = [ "PREFIX=${placeholder "out"}" ];

  desktopItems = [
    (makeDesktopItem rec {
      desktopName = "Just Browsing";
      name = pname;
      exec = pname;
      categories = "Network;" ;
      icon = ./just.png;
      genericName = "Web browser";
    })
  ];

  postInstall = ''
    wrapProgram $out/bin/just --set GI_TYPELIB_PATH "$GI_TYPELIB_PATH" --prefix GIO_EXTRA_MODULES ":" "${glib_networking_gio}"
  '';
}
