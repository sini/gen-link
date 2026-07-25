{
  genLink,
  genMerge,
  mkAspectRegistry,
  ...
}:
let
  ks = {
    nixos = {
      category = "class";
    };
    dbreq = {
      category = "facet";
      contract = "capability";
      option = genMerge.mkOption {
        type = genMerge.types.raw;
        default = null;
      };
    };
  };
  reg = mkAspectRegistry {
    keySemantics = ks;
    modules = [
      {
        config.aspects.app = {
          nixos = { };
          dbreq = {
            requires = [ "read" ];
          };
        };
      }
    ];
  };
  app = reg.config.aspects.app;
  boundA = genLink.bindNode {
    origin = [ "b" ];
    node = app;
    inherit ks;
    holeFillings.dbreq = "filler-A";
  };
  boundB = genLink.bindNode {
    origin = [ "b" ];
    node = app;
    inherit ks;
    holeFillings.dbreq = "filler-B";
  };
  unwired = builtins.tryEval (
    (genLink.bindNode {
      origin = [ "b" ];
      node = app;
      inherit ks;
      holeFillings = { };
    }).id
  );
in
{
  flake.tests.wire.test-bound-id-folds-filling = {
    expr = boundA.id == genLink.nodeId [ "b" ] app;
    expected = false;
  };
  flake.tests.wire.test-distinct-fillings-distinct-id = {
    expr = boundA.id == boundB.id;
    expected = false;
  };
  flake.tests.wire.test-unwired-throws = {
    expr = unwired.success;
    expected = false;
  };
}
