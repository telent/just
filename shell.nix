with import <nixpkgs> {} ;
let just = callPackage ./. {};
in just.overrideAttrs(o: { JUST_HACKING = 1; })
