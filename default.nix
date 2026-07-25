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
  scope ? import "${fetch "gen-scope"}/lib" { inherit prelude; },
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
