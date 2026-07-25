# gen-link REPL — all exports in scope.
let
  nixpkgs = import (builtins.getFlake "nixpkgs") { };
  genLink = import ./.. { };
in
{
  inherit (nixpkgs) lib;
  inherit genLink;
}
// genLink
