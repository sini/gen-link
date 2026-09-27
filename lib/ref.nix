# Node/hole reference parsing (design Resolved decision 4: structured internally, string sugar at the
# surface). A reference is `{ origin; path }` (lists) OR an origin-qualified path-string
# ("self/postgres", "y/apps/media/pg"). `self` is the surface name for origin [] — the importer's own
# registry, whose `self/*` references resolve inside the federation. Slash-splitting/normalization is
# DELEGATED to gen-aspects `keyRef` (the shipped by-key includes parser); gen-link owns only the
# `self` <-> [] surface mapping.
{ prelude, aspects }:
let
  selfName = "self";

  # keyRef's own malformed-reference-string refusals name gen-aspects (den-hoag-7gp66 P1 residue,
  # R6 defect): a caller who reaches it through a gen-link door — `link`'s wire keys, `normalize`'s
  # by-key includes — made the mistake at that door, not inside keyRef. Pre-validate the SAME shape
  # keyRef accepts and refuse under the calling door first (same move as `contract.capability`'s
  # pre-computed `missing`); once validated, keyRef cannot fail here and stays the arbiter for
  # splitting/keying only.
  refShapeOk = v: builtins.isString v || (builtins.isList v && builtins.all builtins.isString v);

  refShapeRefusal =
    door: got:
    throw (
      "${door}: got ${got}, expected a reference: an origin-qualified string "
      + "(\"<origin>/<path>\") or { path; origin ? [ ]; }, each a \"/\"-joined string or a list of strings"
    );

  checkRefShape =
    door: ref:
    if builtins.isString ref then
      (
        if builtins.filter (s: builtins.isString s && s != "") (builtins.split "/" ref) == [ ] then
          refShapeRefusal door "the string \"${ref}\", which has no non-empty segment"
        else
          null
      )
    else if builtins.isAttrs ref && ref ? path then
      if !(refShapeOk (ref.origin or [ ])) then
        refShapeRefusal door (
          "origin = ${builtins.typeOf ref.origin}"
          + (if builtins.isList ref.origin then " holding a non-string" else "")
        )
      else if !(refShapeOk ref.path) then
        refShapeRefusal door (
          "path = ${builtins.typeOf ref.path}"
          + (if builtins.isList ref.path then " holding a non-string" else "")
        )
      else
        null
    else
      refShapeRefusal door (
        if builtins.isAttrs ref then "a set with no 'path' field" else builtins.typeOf ref
      );

  # Parse a reference to `{ __keyRef; origin; path; key }`. `self/<path>` maps to origin []. `door`
  # is the published door the caller invoked — this library's own `parseRef`, or `link`/`normalize`,
  # which parse a reference internally — so a malformed reference is refused by name (R6).
  parseRefAt =
    door: ref:
    let
      r = builtins.seq (checkRefShape door ref) (aspects.keyRef ref);
    in
    if r.origin == [ selfName ] then r // { origin = [ ]; } else r;

  parseRef = parseRefAt "gen-link.parseRef";

  # The origin label datum gen-identity's `hashIdentity` hashes (design §Identity): the "/"-joined
  # origin list.
  originLabel = origin: prelude.concatStringsSep "/" (segs "originLabel" origin);

  # Surface rendering (manifests / errors / keySemantics keys): [] -> "self".
  renderOrigin =
    origin: if segs "renderOrigin" origin == [ ] then selfName else prelude.concatStringsSep "/" origin;

  # An origin is a list of strings; anything else is refused by name (ADR-0025 item 1) rather than
  # aborting inside `concatStringsSep`. The message names the TYPE and never interpolates the value,
  # because interpolating a non-string is itself the coercion abort being replaced.
  segs =
    who: origin:
    if builtins.isList origin && builtins.all builtins.isString origin then
      origin
    else
      throw (
        "gen-link.${who}: got ${builtins.typeOf origin}"
        + (if builtins.isList origin then " holding a non-string" else "")
        + ", expected an origin (a list of strings)"
      );

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
  checkOrigin = segs;
  inherit
    parseRef
    parseRefAt
    originLabel
    renderOrigin
    selfName
    nodeIdentifier
    refIdentifier
    ;
}
