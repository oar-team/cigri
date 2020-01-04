with import <nixpkgs> {};
stdenv.mkDerivation {
  name = "env";
  buildInputs = [
    ruby.devEnv
    postgresql
    pkgconfig
    gnumake
    bundix
  ];
}
