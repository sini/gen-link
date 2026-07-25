{
  genLink,
  mkAspectRegistry,
  ...
}:
let
  mkReg = mkAspectRegistry {
    keySemantics.nixos = {
      category = "class";
    };
    modules = [ { config.aspects.apps.media.pg.nixos = { }; } ];
  };
  stampedA = genLink.originStamp {
    normalized = genLink.normalize mkReg.config.aspects;
    origin = [ "a" ];
  };
  stampedB = genLink.originStamp {
    normalized = genLink.normalize mkReg.config.aspects;
    origin = [ "b" ];
  };
  u = genLink.disjointUnion [
    stampedA
    stampedB
  ];
  pgIds = builtins.filter (id: u.idToNode.${id}.node.key == "apps/media/pg") (
    builtins.attrNames u.idToNode
  );
in
{
  flake.tests.union.test-same-path-distinct-ids = {
    expr = builtins.length pgIds;
    expected = 2;
  };
  flake.tests.union.test-both-in-graph = {
    expr = builtins.all (id: builtins.elem id u.graph.vertices) pgIds;
    expected = true;
  };
}
