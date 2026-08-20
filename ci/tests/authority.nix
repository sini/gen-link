# THE IDENTITY AUTHORITY, ASSERTED WHERE THIS LIBRARY BINDS IT.
#
# gen-link mints nothing. Every id it carries comes from `hashIdentity`, and ADR-0016 ruling 5 makes
# that ONE authority — so which REVISION of it the lock resolves is a property of this library's
# behaviour and not of its dependency hygiene. These cells assert the refusals and the digest law
# that the construction downstream of them relies on.
#
# ★ WHY THE CELLS EXIST RATHER THAN A LOCK INSPECTION. The rest of this suite is green against an
# authority carrying NONE of the four refusals below — it asserts nothing the preimage encoding
# changed, so a green suite is not evidence the pin is current. Without these cells a lock revert is
# invisible, which is the same failure a stale pin already produced once: two mint routes at two
# encodings, every route-crossing lookup missing, and declared holes reading as unwired.
#
# ★★ WHY BOOLEANS HERE AND NOT `expectedError` CELLS. The general objection to a boolean refusal
# cell is that a suite of booleans is equally satisfied by a construction that throws on everything.
# That objection is about a suite asserting WHICH refusal fired; these assert that FOUR DISTINCT
# INPUTS which previously minted now refuse, and the minting control at the end excludes the
# throws-on-everything shape by exhibiting an input the same authority still mints. Upgrading them
# to message-anchored cells is available and is not owed.
#
# THEORY. The authority joins a kind tag to a digest of a canonical pairs preimage (Merkle 1987
# content-address). The preimage is a JSON OBJECT, so the label list is a SET of keys rather than a
# sequence: permuting it is not a different preimage. That is what makes the caller's sort inert and
# what the two order cells below establish together — the equality alone would also hold of a
# formula that read no values at all.
{
  genSchema,
  genIdentity,
  ...
}:
let
  inherit (genIdentity) hashIdentity;

  # A refusal is a throw the caller can catch. `seq` forces past weak head normal form's boundary so
  # a refusal cannot survive as an unforced thunk and read as a mint.
  refuses = e: !(builtins.tryEval (builtins.seq e e)).success;

  v = _: "v";
  originKey =
    k:
    {
      origin = "a";
      key = "b";
    }
    .${k};
in
{
  # ── THE FOUR REFUSALS ──
  # The minting entry gen-link delegates to names two of these as the authority's own: a relatum
  # sharing the reserved `identifier` label is refused as a DUPLICATE IDENTITY KEY, and a zero-key
  # preimage is refused by name. An authority missing them ships that entry with two of its
  # documented refusals silently removed.
  flake.tests.authority.test-refuses-zero-identity-keys = {
    expr = refuses (hashIdentity "aspect" [ ] v);
    expected = true;
  };
  flake.tests.authority.test-refuses-duplicate-identity-key = {
    expr = refuses (
      hashIdentity "aspect" [
        "k"
        "k"
      ] v
    );
    expected = true;
  };
  flake.tests.authority.test-refuses-empty-kind = {
    expr = refuses (hashIdentity "" [ "k" ] v);
    expected = true;
  };
  # The kind tag rides OUTSIDE the digest, so the kind name is the one place a value could reach the
  # identity's structure; the separator is refused there. Values need no such rule — JSON is
  # self-delimiting, which is why a value may carry a colon and a kind may not.
  flake.tests.authority.test-refuses-colon-in-kind = {
    expr = refuses (hashIdentity "as:pect" [ "k" ] v);
    expected = true;
  };

  # ── THE ORDER PAIR ──
  # Together these say the digest is a function of the label-value MAP. Neither says it alone: the
  # first holds of a formula that ignores its labels entirely, the second of an order-SENSITIVE one.
  flake.tests.authority.test-permuted-label-list-is-one-digest = {
    expr =
      hashIdentity "aspect" [
        "origin"
        "key"
      ] originKey == hashIdentity "aspect" [
        "key"
        "origin"
      ] originKey;
    expected = true;
  };
  flake.tests.authority.test-distinct-values-discriminate = {
    expr = hashIdentity "aspect" [ "k" ] (_: "A") == hashIdentity "aspect" [ "k" ] (_: "B");
    expected = false;
  };

  # ── THE MINTING CONTROL ──
  # The four refusals above are a finding only beside an input the same authority accepts.
  flake.tests.authority.test-mints-a-well-formed-input = {
    expr = builtins.isString (hashIdentity "aspect" [ "k" ] v);
    expected = true;
  };
}
