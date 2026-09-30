{
  genMerge,
  aspects,
  ...
}:
{
  gen.ci.examples.demo = (import ../../examples/demo/flake.nix).outputs {
    gen-merge.lib = genMerge;
    gen-aspects.lib = aspects;
  };
}
