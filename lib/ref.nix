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
in
{
  inherit
    parseRef
    originLabel
    renderOrigin
    selfName
    ;
}
