{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-18.09
    rev = "ab118f384727637fa635d18268f00e8b6eface0e";
    sha256 = "046qbx1wi93f3x99di4bdv8xdnh6j18c3w3809knx3h6qkykmgc2";};
  }
