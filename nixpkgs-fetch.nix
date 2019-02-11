{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-19.03
    rev = "929cc78363e6878e044556bd291382eab37bcbed";
    sha256 = "1ghzjk6fq8f2aimp23p45awnfzlcqc20sf7p1xp98myis1sqniwb";};
  }
