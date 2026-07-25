# Resolution manifest (design Resolved decision 1 + §Architecture): a PURE returned value recording
# every cross-origin edge federation bound — each with both endpoints' id_hash and the wire that
# produced it (the flake.lock pattern, Dolstra 2006). Diffable; gen-link writes NOTHING to disk (a
# consumer may serialize a gen-link.lock, out of scope here).
{ prelude }:
let
  entry =
    {
      kind,
      from,
      to,
      via ? null,
    }:
    {
      inherit
        kind
        from
        to
        via
        ;
    };

  # Deterministic ordering for diff stability.
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
