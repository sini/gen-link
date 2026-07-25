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
  identity = import ./identity.nix { inherit prelude aspects schema; };
  normalize = import ./normalize.nix { inherit prelude ref; };
in
{
  _scaffold = true;
  inherit (ref)
    parseRef
    originLabel
    renderOrigin
    ;
  inherit (identity) nodeId keyRefTargetId instantiatedId;
  inherit (normalize) normalize;
  _hasRefPrefix = normalize.hasRefPrefix;
}
