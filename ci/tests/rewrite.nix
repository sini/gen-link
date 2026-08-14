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
  # The identifiers are written as LITERALS rather than derived from the library, which is the whole
  # claim: a vertex name is now the readable origin-qualified reference, so a cell can spell it. A
  # cell deriving them from the same constructor the relabel uses would agree with any constructor.
  mainId = "x/main";
  helperId = "x/helper";
  yTargetId = "y/apps/media/pg";
in
{
  flake.tests.rewrite.test-vertices-are-identifiers = {
    expr = builtins.elem mainId stamped.graph.vertices && builtins.elem helperId stamped.graph.vertices;
    expected = true;
  };
  flake.tests.rewrite.test-byvalue-edge-relabeled = {
    expr = builtins.any (e: e.from == mainId && e.to == helperId) stamped.graph.edges;
    expected = true;
  };
  # The by-key edge relabels to the target's identifier read from the keyRef's OWN origin, never the
  # assigned one (decision 6) — `y`, not the `x` this source was stamped with.
  flake.tests.rewrite.test-bykey-edge-cross-origin = {
    expr = builtins.any (e: e.from == mainId && e.to == yTargetId) stamped.graph.edges;
    expected = true;
  };
  flake.tests.rewrite.test-idtonode-carries-origin = {
    expr = stamped.idToNode.${mainId}.origin;
    expected = [ "x" ];
  };
  # alias genuinely re-names the vertex: the OLD helper identifier must be gone and a new one present.
  flake.tests.rewrite.test-alias-changes-identifier = {
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
