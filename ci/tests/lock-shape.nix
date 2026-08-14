# THE LOCK-SHAPE INVARIANT — each of this repository's locks resolves to EXACTLY ONE gen-schema node.
#
# ★★★ WHY THIS IS AN INVARIANT AND NOT A LANDING-TIME INSPECTION. Both flakes carry a `follows` pair
# collapsing gen-aspects' and gen-scope's gen-schema onto the root's, and it would be easy to read
# the pair as the property. It is not: it is the property's CURRENT DISCHARGE. A lock acquires a
# gen-schema through whatever input acquires one, and this repository's lock already carries TWO
# gen-scope nodes — root's, and gen-resolve's own, which no `follows` here governs. The day
# gen-resolve bumps to a gen-scope that carries a gen-schema input, a second identity authority
# enters through a door the pair does not cover. A `jq` run at landing would have passed once and
# never run again; this cell fails on that future bump.
#
# ★★ WHY IT MATTERS AT ALL. Two gen-schema instances are two content-address formulas for one node.
# gen-aspects supplies the coordinate this library keys its graph by, and gen-scope's minting entry
# mints every federation node's identity — so under two formulas the identity a node carries and the
# identity a relatum resolves to are computed by different functions, and nothing says so. That
# failure has shipped in this ecosystem once already.
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
