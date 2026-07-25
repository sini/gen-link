# gen-link — the cross-flake aspect-federation conductor. Owns ONLY the origin coordinate, the
# disjoint-union-with-relabel, and the resolution manifest; delegates every computation to a sibling.
{
  prelude,
  scope,
  resolve,
  edge,
  schema,
  algebra,
  aspects,
}:
let
  ref = import ./ref.nix { inherit prelude aspects; };
in
{
  _scaffold = true;
  inherit (ref)
    parseRef
    originLabel
    renderOrigin
    ;
}
