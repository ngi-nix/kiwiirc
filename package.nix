{ mkYarnPackage }:

mkYarnPackage rec {
  src = ./.;
  pname = "kiwiirc";
#  distPhase = "false";
  doDist = false;
  buildPhase = ''
    yarn --offline run build
    find . -type d -name dist
    mkdir $out
    mv ./deps/${pname}/dist/* $out/
  '';
}
