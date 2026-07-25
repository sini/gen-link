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
  rewrite = import ./rewrite.nix { inherit prelude scope identity normalize; };
  union = import ./union.nix { inherit prelude scope; };
  facets = import ./facets.nix { inherit prelude; };
  contract = import ./contract.nix { inherit prelude algebra schema; };
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
  inherit (rewrite) originStamp;
  inherit (union) disjointUnion;
  inherit (facets)
    holesOf
    providesOf
    requiresOf
    contractOf
    ;
  inherit (contract) checkCapability checkRefined;
  _recordHas = contract._recordHas;
}
