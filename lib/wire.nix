# Hole binding + instantiation identity (design Federation step 3 + §Identity). A hole is a
# facet-require (Backpack signature); `wire` fills it by a node-REFERENCE (its id — defunctionalized,
# Reynolds 1972), never a raw closure. The filling folds into the aspect's instantiation identity
# (applicative, Leroy 1995). `wire` fills HOLES ONLY; `includes` are concrete graph edges resolved
# elsewhere. An unwired required facet is a LOUD, named error (missing, not ambiguous — decision 7).
{
  prelude,
  identity,
  facets,
}:
let
  bindNode =
    {
      origin,
      node,
      ks,
      holeFillings,
    }:
    let
      holes = facets.holesOf ks node;
      unfilled = builtins.filter (h: !(holeFillings ? ${h})) holes;
    in
    if unfilled != [ ] then
      throw "gen-link.wire: aspect '${node.key}' has unwired required facet(s): ${builtins.concatStringsSep ", " unfilled}"
    else
      {
        id = identity.instantiatedId origin node holeFillings;
        inherit node origin holeFillings;
      };
in
{
  inherit bindNode;
}
