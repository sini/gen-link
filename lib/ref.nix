# Node/hole reference parsing (design Resolved decision 4: structured internally, string sugar at the
# surface). A reference is `{ origin; path }` (lists) OR an origin-qualified path-string
# ("self/postgres", "y/apps/media/pg"). `self` is the surface name for origin [] — the importer's own
# registry, whose `self/*` references resolve inside the federation. Slash-splitting/normalization is
# DELEGATED to gen-aspects `keyRef` (the shipped by-key includes parser); gen-link owns only the
# `self` <-> [] surface mapping.
{ prelude, aspects }:
let
  selfName = "self";

  # Parse a reference to `{ __keyRef; origin; path; key }`. `self/<path>` maps to origin [].
  parseRef =
    ref:
    let
      r = aspects.keyRef ref;
    in
    if r.origin == [ selfName ] then r // { origin = [ ]; } else r;

  # The origin label datum hashIdentity hashes (design §Identity): the "/"-joined origin list.
  originLabel = origin: prelude.concatStringsSep "/" origin;

  # Surface rendering (manifests / errors / keySemantics keys): [] -> "self".
  renderOrigin = origin: if origin == [ ] then selfName else prelude.concatStringsSep "/" origin;

  # ── THE IDENTIFIER ──
  # ADR-0016 ruling 5 separates IDENTIFIER — the name a node carries as a vertex, what an edge
  # endpoint names, what an emitter writes when it names a relatum — from IDENTITY, the derived
  # content-address. The identifier of a federation node is its origin-qualified reference: the same
  # string a `wire` key is written in, the same string `parseRef` consumes, and the same string
  # `normalize` already builds behind the `@ref:` prefix. It is not invented here — it is the name
  # this library was already speaking, promoted from a rendering to the addressing.
  #
  # `aspects.key` rather than the node's `.key` attribute, because that is the reading a reference
  # joins against: a keyRef's key is `pathKey` over its path segments, and `aspects.key` is `pathKey`
  # over the node's aspect chain. Reading `.key` here would join the two coordinates by a spelling
  # that nothing keeps in step.
  nodeIdentifier = origin: node: "${renderOrigin origin}/${aspects.key node}";

  # The same coordinate read off a parsed reference. `refIdentifier (parseRef r)` and
  # `nodeIdentifier` agree exactly where the federation's two id routes used to agree by hash
  # equality — but by STRING equality, which is a property of the two constructions rather than of
  # a lock collapsing two authorities onto one.
  refIdentifier = r: "${renderOrigin r.origin}/${r.key}";
in
{
  inherit
    parseRef
    originLabel
    renderOrigin
    selfName
    nodeIdentifier
    refIdentifier
    ;
}
