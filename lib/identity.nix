# gen-link identity — the origin coordinate + instantiation identity, routed through the canonical
# content-address formula (gen-schema `hashIdentity`; Merkle 1987 content-address, Dolstra 2006 lock
# discipline). gen-link NEVER calls sha256: holeless ids delegate to gen-aspects `aspectId`, and
# hole-filled (instantiation) ids call gen-schema `hashIdentity` DIRECTLY with the extended key list.
#
# Those are TWO routes to the formula, and lib/link.nix joins the ids they mint BY EQUALITY, so the
# formula has to be ONE. That is not inherent: `aspectId` resolves `hashIdentity` from gen-aspects' own
# gen-schema input, not from this module's. It is the LOCK that makes it one —
# `gen-aspects.inputs.gen-schema.follows = "gen-schema"` in both flake.nix and ci/flake.nix collapses
# the two to a single instance. Without that follows the routes are two formulas whenever the pins
# differ, every route-crossing lookup misses, and declared holes read as unwired.
#
# Instantiation-creates-identity is APPLICATIVE (Leroy 1995: same fillings => same id); fillers are
# defunctionalized to node-ids before hashing (Reynolds 1972).
{
  prelude,
  aspects,
  schema,
}:
let
  # Base node id — pure delegation to the shipped uniform content-address (plain/wrapped-fn/guard).
  # origin is a path-segment LIST; [] => today's `.key` partition preserved (origin-invariant).
  nodeId = origin: node: aspects.aspectId origin node;

  # Edge-target id for a by-KEY include (a keyRef). MUST NOT route through `aspectId`/`identity.key`
  # on the bare keyRef: `identity.key` would recompute `pathKey (aspectPath ref)` = "<anon>" (a keyRef
  # carries no meta.aspect-chain / name). gen-link reads the keyRef's OWN origin + key and hashes
  # through the SAME formula, so a keyRef target id byte-equals the id of the node it names.
  keyRefTargetId =
    ref:
    schema.hashIdentity "aspect" [ "origin" "key" ] (
      k:
      {
        origin = prelude.concatStringsSep "/" ref.origin;
        key = ref.key;
      }
      .${k}
    );

  # Instantiation identity (Backpack signatures / applicative functors). holeFillings :: { <facet> =
  # <fillerId>; } — fillers already resolved to node-ids. Empty => byte-identical to `nodeId` (holeless
  # invariant). Each hole contributes a `hole:<facet>=<fillerId>` preimage segment; keys are SORTED by
  # gen-link (hashIdentity hashes in list order), making the digest filling-order-independent. The hash
  # is gen-schema's; gen-link supplies only the key list + valueOf.
  instantiatedId =
    origin: node: holeFillings:
    if holeFillings == { } then
      nodeId origin node
    else
      let
        facets = prelude.sort (a: b: a < b) (builtins.attrNames holeFillings);
        holeKeys = map (f: "hole:${f}") facets;
        valueOf =
          k:
          if k == "origin" then
            prelude.concatStringsSep "/" origin
          else if k == "key" then
            aspects.key node
          else
            holeFillings.${prelude.removePrefix "hole:" k};
      in
      schema.hashIdentity "aspect" (
        [
          "origin"
          "key"
        ]
        ++ holeKeys
      ) valueOf;
in
{
  inherit nodeId keyRefTargetId instantiatedId;
}
