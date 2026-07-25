{
  genLink,
  aspects,
  mkAspectRegistry,
  ...
}:
let
  # A real aspect node at path apps/media/pg (plain submodule with a class key).
  reg = mkAspectRegistry {
    keySemantics.nixos = {
      category = "class";
    };
    modules = [ { config.aspects.apps.media.pg.nixos = { }; } ];
  };
  pg = reg.config.aspects.apps.media.pg;
  refY = genLink.parseRef "y/apps/media/pg";
in
{
  # nodeId is pure delegation to the shipped aspectId.
  flake.tests.identity.test-nodeid-delegates = {
    expr = genLink.nodeId [ "y" ] pg == aspects.aspectId [ "y" ] pg;
    expected = true;
  };
  # origin discriminates: same node, different origin -> different id.
  flake.tests.identity.test-origin-discriminates = {
    expr = genLink.nodeId [ "a" ] pg == genLink.nodeId [ "b" ] pg;
    expected = false;
  };
  # keyRef target id equals the id of the node it names (discrimination correct)...
  flake.tests.identity.test-keyref-target-matches-node = {
    expr = genLink.keyRefTargetId refY == aspects.aspectId [ "y" ] pg;
    expected = true;
  };
  # ...and naively aspectId-ing the bare keyRef would NOT (the "<anon>" gotcha).
  flake.tests.identity.test-keyref-gotcha-avoided = {
    expr = aspects.aspectId [ "y" ] refY == aspects.aspectId [ "y" ] pg;
    expected = false;
  };
  # holeless instantiation id == nodeId.
  flake.tests.identity.test-holeless-equals-nodeid = {
    expr = genLink.instantiatedId [ "y" ] pg { } == genLink.nodeId [ "y" ] pg;
    expected = true;
  };
  # applicative: distinct fillings -> distinct ids.
  flake.tests.identity.test-distinct-fillings-distinct-id = {
    expr =
      genLink.instantiatedId [ "y" ] pg { db = "id-A"; }
      == genLink.instantiatedId [ "y" ] pg { db = "id-B"; };
    expected = false;
  };
  # filling-order independence (keys sorted before hashing).
  flake.tests.identity.test-filling-order-independent = {
    expr =
      genLink.instantiatedId [ "y" ] pg {
        a = "1";
        b = "2";
      } == genLink.instantiatedId [ "y" ] pg {
        b = "2";
        a = "1";
      };
    expected = true;
  };
}
