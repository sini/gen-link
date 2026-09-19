# THE LOCK-SHAPE INVARIANT — each of this repository's locks resolves to EXACTLY ONE gen-schema
# node AND exactly one gen-identity REVISION.
#
# ★★★ THE TWO ARMS ARE COUNTED IN DIFFERENT UNITS, AND THAT IS THE WHOLE OF WHAT THIS FILE LEARNED.
# The property both arms are about is "one authority" — ADR-0034's *the count of minting authorities
# is ONE* — and an authority is a FUNCTION, never a lock entry. Node count is a PROXY for it, and on
# 2026-09-18 the proxy and the property came apart: the ecosystem relock put `gen-types` on a
# `gen-identity` input, so `gen-merge → gen-types → gen-identity` opened as a door and these locks
# went from one gen-identity node to three and four — ALL AT ONE REVISION, `11569805a`. Three cells
# fired. Nothing was broken: a digest computed through any of those nodes is byte-identical, because
# it is the same code. The headline disagreed while the thing underneath was the same, which is what
# a proxy does when the world moves under it.
#
# ★★ SO THE MINT'S ARM COUNTS REVISIONS AND THE REFLECTION ARM COUNTS NODES, each because of what
# DETERMINES ITS VALUE, and neither by symmetry with the other. gen-identity is a leaf, so its source
# determines it and a revision is an authority. gen-schema takes four inputs, so its source does NOT
# determine it and only a node is. `test-the-mint-is-a-leaf-…` is what keeps the first of those from
# being an assumption, and the arming cells are what keep either from passing vacuously.
#
# ★ IT IS A NARROWER PREDICATE IN ONE DIMENSION AND A STRICTLY STRONGER ONE IN THE DIMENSION THAT
# MATTERS: two DIFFERENT revisions of the mint reachable in one closure is two encoding formulas for
# one node, and that still fires — the arming below seeds exactly it. What it no longer fires on is a
# lock writing the same code down more than once, which was never the condition.
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
  #
  # ★★★ IT ARMS THE REVISION COUNTER, SO IT INJECTS A SECOND REVISION OF gen-identity ITSELF rather
  # than redirecting the input at some other node. Redirecting at, say, the root's gen-prelude node
  # would move this count too — but only because gen-prelude's revision HAPPENS to differ, which is
  # a fact about an unrelated library and not about what is being armed. The seeded node is the
  # literal violation the invariant exists for: two encoding formulas for one node, reachable in one
  # closure. `sedRev` is a revision no gen library can carry, so the arm cannot pass by coincidence.
  sedRev = "0000000000000000000000000000000000000000";
  armedIdentity =
    lock:
    let
      mint = lock.nodes.${lock.nodes.root.inputs.gen-identity};
    in
    walkOf (
      lock
      // {
        nodes = lock.nodes // {
          gen-identity-second = mint // {
            locked = mint.locked // {
              rev = sedRev;
            };
          };
          gen-aspects = lock.nodes.gen-aspects // {
            inputs = lock.nodes.gen-aspects.inputs // {
              gen-identity = "gen-identity-second";
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
  # ── THE REFLECTION ARM STAYS IN NODES, AND NOT BY INERTIA ──
  # ★★ THE ARGUMENT THAT MOVED THE MINT'S ARM TO REVISIONS DOES NOT REACH THIS ONE, so changing it by
  # symmetry would be unsound. gen-schema is NOT a leaf — measured at `c41e5dc96` its lock node
  # declares four inputs (`gen-algebra`, `gen-identity`, `gen-merge`, `gen-prelude`) — so its `lib`
  # is a function of its source AND of what those four resolve to. Two gen-schema nodes at ONE
  # revision resolving different `gen-merge` nodes are two different `isPrimitiveOption`s, which is
  # precisely the silent disagreement this arm exists for. The node is what decides the value here,
  # so the node is the unit; `test-the-mint-is-a-leaf-…` above is what will say if that ever stops
  # being true of gen-identity.
  flake.tests.lock-shape.test-root-lock-resolves-one-gen-schema = {
    expr = root.countUnder "gen-schema";
    expected = 1;
  };
  flake.tests.lock-shape.test-ci-lock-resolves-one-gen-schema = {
    expr = ci.countUnder "gen-schema";
    expected = 1;
  };

  # ── THE MINT'S ARM IS COUNTED IN REVISIONS ──
  # The property is ADR-0034's "the count of minting authorities is ONE", and an authority is a
  # FUNCTION — `hashIdentity` — not a lock entry. gen-identity is a LEAF (the cell below asserts it
  # rather than assuming it), so its `lib` is a function of its source alone and every node at one
  # revision IS one authority: a digest computed through any of them is byte-identical, because it is
  # the same code. What two DIFFERENT revisions give is two encoding formulas for one node, and that
  # is the condition this fires on.
  flake.tests.lock-shape.test-root-lock-resolves-one-gen-identity-revision = {
    expr = builtins.length (root.revsUnder "gen-identity");
    expected = 1;
  };
  flake.tests.lock-shape.test-ci-lock-resolves-one-gen-identity-revision = {
    expr = builtins.length (ci.revsUnder "gen-identity");
    expected = 1;
  };

  # ★★★ THE CONJUNCT THAT EARNS THE UNIT ABOVE, AND IT IS NOT A FORMALITY. `revsUnder` states
  # something about the VALUE only while the source determines the value. gen-identity declares NO
  # inputs, so it does; the day it declares one, two nodes at one revision may resolve that input
  # differently and evaluate to two different mints, and counting revisions would report ONE while
  # the invariant is broken. This cell is what makes that arrive as a RED naming the new input
  # instead of as a silent pass, and it is the reason the gen-schema cells below keep the other unit.
  flake.tests.lock-shape.test-the-mint-is-a-leaf-so-its-revision-determines-it = {
    expr = [
      (root.inputLabelsUnder "gen-identity")
      (ci.inputLabelsUnder "gen-identity")
    ];
    expected = [
      [ ]
      [ ]
    ];
  };

  # The gen-identity counter is armed on its own terms: a counter that reported 1 because it cannot
  # see a second ENCODING instance would pass forever, and the gen-schema arming below says nothing
  # about it. The expectation is unchanged at `[ 2 2 ]` and its UNIT is not — it now reads two
  # distinct REVISIONS, which is what a second encoding formula is. Four nodes at one revision, the
  # live state of both locks, is one.
  flake.tests.lock-shape.test-arming-a-second-identity-instance-is-counted = {
    expr = [
      (builtins.length ((armedIdentity rootLock).revsUnder "gen-identity"))
      (builtins.length ((armedIdentity ciLock).revsUnder "gen-identity"))
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
