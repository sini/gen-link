# Resolution manifest (design Resolved decision 1 + §Architecture): a PURE returned value recording
# every cross-origin edge federation bound — each endpoint under its IDENTIFIER and its node KIND,
# plus the wire that produced it (the flake.lock pattern, Dolstra 2006). Diffable; gen-link writes
# NOTHING to disk (a consumer may serialize a gen-link.lock, out of scope here).
#
# ── WHAT A ROW CARRIES, AND WHY IT CARRIES EXACTLY THIS ──
# ADR-0016 ruling 5 rules the derived content-address INTERNAL ADDRESSING ONLY, so **no identity ever
# reaches a row**. What a row carries instead is the identity function's own INPUTS: the endpoints'
# identifiers and their kinds. That is not a weaker record — it is the DISCOVERABLE one, because a
# digest is a computed value a reader cannot read back, while the coordinates are what a tool
# reproduces and queries the output from, and the identity rebuilds from them.
#
# ★★ THE KIND IS WHAT KEEPS THAT REBUILD TOTAL ONCE A FEDERATION MIXES KINDS. An identity is
# `"<kind>:" + digest`, so the kind is only the tag prefix — recoverable from an identity by
# splitting on the first colon, and recoverable from NOWHERE once the identity stops being
# serialized. One string per endpoint closes that gap, and nothing smaller does: without it a
# consumer holding a row of a mixed-kind federation cannot name the kind to mint with.
#
# ★★★ THE FIELD NAMES ARE DELIBERATELY NOT `kind`. This record already has a `kind`, and it means the
# ROW's sort — `"includes"` or `"hole"`, a property of the RELATION. A node's kind is a different
# vocabulary on a different substrate, so the endpoint fields are qualified by the endpoint they
# describe: `from`/`fromKind`, `to`/`toKind`. Reusing `kind` for both would put two vocabularies on
# one name, which is the conflation this whole migration exists to remove rather than relocate.
#
# ★ BOTH ARE REQUIRED FORMALS, NOT DEFAULTED. A defaulted endpoint kind would answer for a node
# whose kind nobody supplied — silently claiming one kind for a node of another, which is precisely
# the mixed-kind failure the field exists to prevent. An absent kind is a caller that has not decided,
# and that must be a refusal rather than a guess.
{ prelude }:
let
  entry =
    {
      kind,
      from,
      fromKind,
      to,
      toKind,
      via ? null,
    }:
    {
      inherit
        kind
        from
        fromKind
        to
        toKind
        via
        ;
    };

  # Deterministic ordering for diff stability.
  #
  # ★ The endpoint kinds are deliberately absent from the key, and the absence is reasoned rather
  # than an omission: a node has ONE kind, so the kinds are a function of `from` and `to` and cannot
  # separate two rows this key already ties. Adding them would lengthen the key without making it
  # more total.
  order =
    entries:
    prelude.sort (
      a: b:
      "${a.kind}|${a.from}->${a.to}|${toString a.via}" < "${b.kind}|${b.from}->${b.to}|${toString b.via}"
    ) entries;
in
{
  inherit entry order;
}
