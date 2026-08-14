# Standalone (non-flake) entry. Flake consumers should use the `.lib` output.
#
# gen-link is Class B: gen-prelude base + {gen-scope, gen-resolve, gen-edge, gen-schema, gen-algebra,
# gen-aspects}. This shim derives each from the pinned flake.lock (content-addressed via narHash, so
# it stays pure). Each sibling flake `.lib` self-resolves its own deps, so we import each sibling's
# standalone entry, which self-constructs. Pass any dep explicitly to override.
{
  lock ? builtins.fromJSON (builtins.readFile ./flake.lock),
  fetch ? name: builtins.fetchTree (lock.nodes.${lock.nodes.root.inputs.${name}}.locked),
  prelude ? import "${fetch "gen-prelude"}/lib",
  # gen-scope's minting entry is where every federation node's identity comes from, so the authority
  # it reaches must be the one this shim derived — not the one gen-scope's own lock would
  # self-construct. Two instances are two content-address formulas for one node. They happen to agree
  # at today's pins, which is exactly why the threading is here rather than a digest comparison: what
  # makes the count one is the dataflow, and agreement between two instances is what a divergence
  # looks like right up until the revision where it is not.
  scope ? import "${fetch "gen-scope"}" { inherit prelude schema; },
  resolve ? import "${fetch "gen-resolve"}" { },
  edge ? import "${fetch "gen-edge"}" { },
  schema ? import "${fetch "gen-schema"}" { inherit prelude; },
  algebra ? import "${fetch "gen-algebra"}/lib",
  aspects ? import "${fetch "gen-aspects"}" { },
  ...
}:
import ./lib {
  inherit
    prelude
    scope
    resolve
    edge
    schema
    algebra
    aspects
    ;
}
