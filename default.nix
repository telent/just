{ stdenv
, callPackage
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
, makeWrapper
, writeText
}:
let fennel = fetchurl {
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
in stdenv.mkDerivation {
  pname = "just";
  version = "0.1";
  src =./.;
  inherit fennel;

  # this will have to go into a makeWrapper thingy when we
  # get to the point of producing an actual package
  GIO_EXTRA_MODULES = "${glib-networking}/lib/gio/modules";
  buildInputs = [ lua gtk3 webkitgtk gobject-introspection.dev
                  glib-networking  ];
  nativeBuildInputs = [ lua makeWrapper ];

  makeFlags = [ "PREFIX=${placeholder "out"}" ];
  postInstall = ''
    wrapProgram $out/bin/just  --set GI_TYPELIB_PATH "$GI_TYPELIB_PATH"
  '';
}
