{
  genLink,
  aspects,
  mkAspectRegistry,
  ...
}:
let
  reg = mkAspectRegistry {
    keySemantics.nixos = {
      category = "class";
    };
    modules = [
      (
        { config, ... }:
        {
          config.aspects = {
            helper.nixos = { };
            main = {
              nixos = { };
              includes = [
                config.aspects.helper
                (aspects.keyRef "y/apps/media/pg")
              ];
            };
          };
        }
      )
    ];
  };
  norm = genLink.normalize reg.config.aspects;
  stamped = genLink.originStamp {
    normalized = norm;
    origin = [ "x" ];
  };
  mainId = genLink.nodeId [ "x" ] reg.config.aspects.main;
  helperId = genLink.nodeId [ "x" ] reg.config.aspects.helper;
  yTargetId = genLink.keyRefTargetId (genLink.parseRef "y/apps/media/pg");
in
{
  flake.tests.rewrite.test-vertices-are-ids = {
    expr = builtins.elem mainId stamped.graph.vertices && builtins.elem helperId stamped.graph.vertices;
    expected = true;
  };
  flake.tests.rewrite.test-byvalue-edge-relabeled = {
    expr = builtins.any (e: e.from == mainId && e.to == helperId) stamped.graph.edges;
    expected = true;
  };
  flake.tests.rewrite.test-bykey-edge-cross-origin = {
    expr = builtins.any (e: e.from == mainId && e.to == yTargetId) stamped.graph.edges;
    expected = true;
  };
  flake.tests.rewrite.test-idtonode-carries-origin = {
    expr = stamped.idToNode.${mainId}.origin;
    expected = [ "x" ];
  };
  # alias genuinely changes identity: the OLD helper id must be gone and a genuinely NEW id present.
  flake.tests.rewrite.test-alias-changes-id = {
    expr =
      let
        aliased = genLink.originStamp {
          normalized = norm;
          origin = [ "x" ];
          alias.helper = "helper-renamed";
        };
        oldGone = !(builtins.elem helperId aliased.graph.vertices);
        newAppeared = builtins.any (v: !(builtins.elem v stamped.graph.vertices)) aliased.graph.vertices;
      in
      {
        inherit oldGone newAppeared;
      };
    expected = {
      oldGone = true;
      newAppeared = true;
    };
  };
  # two sources aliasing the SAME source path to DIFFERENT names must not collide.
  flake.tests.rewrite.test-alias-no-collision = {
    expr =
      let
        s1 = genLink.originStamp {
          normalized = norm;
          origin = [ "x" ];
          alias.helper = "helper-one";
        };
        s2 = genLink.originStamp {
          normalized = norm;
          origin = [ "x" ];
          alias.helper = "helper-two";
        };
        h1 = builtins.filter (v: !(builtins.elem v stamped.graph.vertices)) s1.graph.vertices;
        h2 = builtins.filter (v: !(builtins.elem v stamped.graph.vertices)) s2.graph.vertices;
      in
      (builtins.head h1) != (builtins.head h2);
    expected = true;
  };
}
