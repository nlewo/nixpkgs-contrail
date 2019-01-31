{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-18.09
    rev = "f2a1a4e93be2d76720a6b96532b5b003cc769312";
    sha256 = "1yjk6ffnm6ahj34yy2q1g5wpdx0m1j7h8i4bzn4x78g9chb0ppy4";};
  }
