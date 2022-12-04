with import <nixpkgs> {} ;
let just = callPackage ./. {};
in just.overrideAttrs(o: {
  nativeBuildInputs = o.nativeBuildInputs ++ [ pkgs.socat ];
  JUST_HACKING = 1;
})
