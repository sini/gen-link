# gen-link — the cross-flake aspect-federation conductor. Owns ONLY the origin coordinate, the
# disjoint-union-with-relabel, and the resolution manifest; delegates every computation to a sibling.
#
# ★ THERE IS NO IDENTITY SURFACE HERE, AND THE ABSENCE IS THE DESIGN. ADR-0016 ruling 5 rules ONE
# minting authority; this library reaches it through gen-scope's staged minting entry and holds no
# second route to it — no per-node minting function, no re-export of a gen-scope name, no view of the
# frozen set. Every id a consumer reads comes back on `link`'s result, and the identity of a node is
# a FIELD on that node rather than its name. What this library names things by is the IDENTIFIER,
# which is the federation reference and needs no constructor: a consumer that wants one writes
# `"${renderOrigin origin}/${key}"`. That it can be written by hand is the point — under the previous
# addressing the name was a digest, and a consumer had no way to say it.
{
  prelude,
  scope,
  view,
  schema,
  algebra,
  aspects,
}:
let
  ref = import ./ref.nix { inherit prelude aspects; };
  normalize = import ./normalize.nix { inherit prelude ref; };
  rewrite = import ./rewrite.nix {
    inherit
      prelude
      scope
      ref
      normalize
      ;
  };
  union = import ./union.nix { inherit prelude scope; };
  facets = import ./facets.nix { inherit prelude; };
  contract = import ./contract.nix { inherit prelude algebra schema; };
  manifest = import ./manifest.nix { inherit prelude; };
  link = import ./link.nix {
    inherit
      prelude
      scope
      view
      ref
      normalize
      rewrite
      union
      facets
      contract
      manifest
      ;
  };
in
{
  _scaffold = true;
  inherit (ref)
    parseRef
    originLabel
    renderOrigin
    ;
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
  inherit (link) link;
  inherit (manifest) entry order;
}
