{
  genLink,
  genMerge,
  aspects,
  ...
}:
let
  demo = import ../../examples/demo/demo.nix {
    inherit genLink aspects;
    merge = genMerge;
  };
in
{
  flake.tests.demo.test-manifest-nonempty = {
    expr = builtins.length demo.manifest >= 1;
    expected = true;
  };
  flake.tests.demo.test-manifest-records-wired-hole = {
    expr = builtins.any (e: e.kind == "hole" && e.via == "dbreq") demo.manifest;
    expected = true;
  };
}
