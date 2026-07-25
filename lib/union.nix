# Disjoint union (design §statement 2 / Federation step 2): overlay the origin-stamped subgraphs.
# `overlay` is the union monoid — commutative, associative, idempotent (Mokhov 2017 §monoid). Origin
# has already made every node id origin-qualified, so the union is collision-free BY CONSTRUCTION: two
# flakes' `apps/media/pg` are distinct nodes. gen-link holds no graph between calls; the merged graph
# is a gen-scope value returned to the caller (accessor discipline).
{ prelude, scope }:
let
  disjointUnion =
    stamped: # list of { graph; idToNode; }
    {
      graph = scope.overlays (map (s: s.graph) stamped);
      idToNode = prelude.foldl' (acc: s: acc // s.idToNode) { } stamped;
    };
in
{
  inherit disjointUnion;
}
