# THE LOCK-SHAPE INVARIANT — each of this repository's locks resolves to EXACTLY ONE gen-schema
# node AND exactly one gen-identity node.
#
# ★★★ WHY THIS IS AN INVARIANT AND NOT A LANDING-TIME INSPECTION. Both flakes carry a `follows` pair
# collapsing gen-aspects' and gen-scope's gen-schema onto the root's, and it would be easy to read
# the pair as the property. It is not: it is the property's CURRENT DISCHARGE. A lock acquires a
# gen-schema through whatever input acquires one, and a door the pair does not cover can open
# without anything here changing.
#
# ★★ THAT IS NOT A HYPOTHETICAL, AND THE HISTORY IS KEPT BECAUSE THE INVARIANT EARNED IT. This
# repository's lock used to carry TWO gen-scope nodes — root's, and gen-resolve's own, which no
# `follows` here governed. This cell NAMED that door before it opened ("the day gen-resolve bumps
# to a gen-scope that carries a gen-schema input, a second identity authority enters through a door
# the pair does not cover") and then FAILED on the bump that opened it. A `jq` run at landing would
# have passed once and never run again. gen-resolve has since left this repository entirely — its
# `reference` was the whole of the dependence and gen-view's construct replaced it — so that
# particular door is gone rather than guarded. The invariant stays, because the NEXT one will not
# be announced either.
#
# ★★ WHY IT MATTERS, AND IT IS NOW TWO REASONS OVER TWO LABELS — the invariant SPLIT rather than
# moved. The content-address formula left gen-schema for gen-identity, a dependency-free leaf, so
# the single sentence that used to cover both halves no longer does:
#
#   • at `gen-identity` — two instances are two ENCODING formulas. Two nodes minted through
#     different pins can carry digests that differ while naming the same value, so the identity a
#     node carries and the identity a relatum resolves to are computed by different functions and
#     nothing says so. That failure has shipped in this ecosystem once already.
#   • at `gen-schema` — two instances remain two REFLECTION formulas. `isPrimitiveOption` decides
#     which of a kind's options count as identity keys, and `identityHashForKind` must agree with
#     what `mkIdentityModule` stamped. Disagreement there is SILENT, because both answers are
#     well-formed hashes over the same encoder.
#
# gen-aspects supplies the coordinate this library keys its graph by and gen-scope's minting entry
# mints every federation node's identity, so both labels reach the same nodes by different routes.
# The existing arm keeps its subject and loses only its stated reason; the new arm is not a copy of
# it.
#
# THE COUNT IS OF DISTINCT NODES REACHED UNDER AN INPUT LABELLED `gen-schema`, WALKED FROM `.root`,
# never of lock entries whose key spelling matches — see `_fixtures/lock-walk.nix` for why the two
# are different questions and why their agreeing is not an argument.
#
# Reading repository files from a cell is the move `purity.nix` next door already makes.
{
  lib,
  ...
}:
let
  walkOf = lock: import ./_fixtures/lock-walk.nix { inherit lib lock; };

  rootLock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  ciLock = builtins.fromJSON (builtins.readFile ../flake.lock);

  root = walkOf rootLock;
  ci = walkOf ciLock;

  # ── THE ARMING ──
  # A counter that reported 1 because it cannot see a second instance would pass this suite forever.
  # Redirecting gen-aspects' `gen-schema` input away from the followed node makes the walk reach two
  # DISTINCT nodes under that label, and the count must move. Nothing about the real lock changes.
  # The gen-identity arming is written separately rather than parameterised over the label: the two
  # invariants have different reasons, and a shared helper would invite a later reader to assume one
  # arming covers both when only its label differs.
  armedIdentity =
    lock:
    walkOf (
      lock
      // {
        nodes = lock.nodes // {
          gen-aspects = lock.nodes.gen-aspects // {
            inputs = lock.nodes.gen-aspects.inputs // {
              gen-identity = lock.nodes.root.inputs.gen-prelude;
            };
          };
        };
      }
    );

  armed =
    lock:
    walkOf (
      lock
      // {
        nodes = lock.nodes // {
          gen-aspects = lock.nodes.gen-aspects // {
            inputs = lock.nodes.gen-aspects.inputs // {
              gen-schema = lock.nodes.root.inputs.gen-prelude;
            };
          };
        };
      }
    );

  # ── THE ROOT GUARD ──
  # A walk whose root resolves to no node walks an empty graph and reports ZERO for every label,
  # which reads as the invariant holding. Being wrongly rooted must be loud, not green.
  wronglyRooted = builtins.tryEval (
    (walkOf (rootLock // { root = "no-such-node"; })).countUnder "gen-schema"
  );
in
{
  flake.tests.lock-shape.test-root-lock-resolves-one-gen-schema = {
    expr = root.countUnder "gen-schema";
    expected = 1;
  };
  flake.tests.lock-shape.test-ci-lock-resolves-one-gen-schema = {
    expr = ci.countUnder "gen-schema";
    expected = 1;
  };

  flake.tests.lock-shape.test-root-lock-resolves-one-gen-identity = {
    expr = root.countUnder "gen-identity";
    expected = 1;
  };
  flake.tests.lock-shape.test-ci-lock-resolves-one-gen-identity = {
    expr = ci.countUnder "gen-identity";
    expected = 1;
  };

  # The gen-identity counter is armed on its own terms: a counter that reported 1 because it cannot
  # see a second ENCODING instance would pass forever, and the gen-schema arming below says nothing
  # about it.
  flake.tests.lock-shape.test-arming-a-second-identity-instance-is-counted = {
    expr = [
      ((armedIdentity rootLock).countUnder "gen-identity")
      ((armedIdentity ciLock).countUnder "gen-identity")
    ];
    expected = [
      2
      2
    ];
  };

  flake.tests.lock-shape.test-arming-a-second-instance-is-counted = {
    expr = [
      ((armed rootLock).countUnder "gen-schema")
      ((armed ciLock).countUnder "gen-schema")
    ];
    expected = [
      2
      2
    ];
  };

  # The counter is shown able to see a multiply-instantiated library on the REAL locks, so the two
  # cells above are reading a live walk rather than a walk that reaches almost nothing.
  flake.tests.lock-shape.test-a-multiply-instantiated-input-is-seen = {
    expr = root.countUnder "gen-prelude" > 1 && ci.countUnder "gen-prelude" > 1;
    expected = true;
  };
  flake.tests.lock-shape.test-an-absent-label-reaches-nothing = {
    expr = [
      (root.countUnder "zzqqNoSuchInput")
      (ci.countUnder "zzqqNoSuchInput")
    ];
    expected = [
      0
      0
    ];
  };
  flake.tests.lock-shape.test-a-wrongly-rooted-walk-refuses = {
    expr = wronglyRooted.success;
    expected = false;
  };
}
