# THE SECOND TEST OUTPUT — cells whose subject is an ERROR MESSAGE, and why they cannot live in
# `flake.tests`.
#
# `link` refuses several different things about a federation, and a caller must act differently on
# each: a declared hole nothing wired is an authoring omission, a reference naming nothing in the
# federation is a coordinate or a missing source. THAT each refuses is a boolean and `tryEval` can
# assert it — and the suite already does, at `link.test-unwired-required-facet-throws` and
# `link.test-absent-wire-target-throws`. WHICH one refused is a claim about the message, and
# `tryEval` returns `{ success, value }` and discards the text, so a pair of booleans is equally
# satisfied by a construction with one refusal in it and a reworded message regresses nothing any
# cell reads. `expectedError` is the assertion for that, and this is where it goes.
#
# ★ WHY A SECOND OUTPUT RATHER THAN A SECOND SUITE. The batch asserter behind `checks.default`
# evaluates `t.expr == t.expected` UNCONDITIONALLY and quantifies over `config.flake.tests` and
# nothing else, so a cell with no `expected` and a throwing `expr` CRASHES that gate rather than
# failing it. Hosting these on `flake.testsError` puts them outside that quantifier while keeping
# them live on the nix-unit path. The split is structural, not conventional: this file is not under
# `./tests`, which is the whole of `testModules`, so nothing about which cells land in which output
# depends on a filter predicate or an ignore convention.
#
#   nix-unit --flake ./ci#tests        # the suites
#   nix-unit --flake ./ci#testsError   # these cells
#
# ★★ `expectedError.msg` IS SEARCHED, NOT WHOLE-MATCHED, so a pattern naming a prefix of the message
# passes against a message that says something else after it — which would make these cells agree
# with the very rewording they exist to catch. Every pattern below is anchored at both ends and
# built by ESCAPING THE LITERAL TEXT rather than by hand: a hand-written pattern is one forgotten
# backslash away from a metacharacter matching something it was meant to spell.
{
  lib,
  genLink,
  genMerge,
  mkAspectRegistry,
  ...
}:
let
  fixtures = import ./tests/_fixtures/link.nix { inherit genLink genMerge mkAspectRegistry; };
  inherit (fixtures) linkManifest unwiredHoleRefusal unknownTargetRefusal;

  # The message, pinned to the byte. nixpkgs' metacharacter set is the one the pattern is read under.
  exactly = msg: "^" + lib.escapeRegex msg + "$";
in
{
  # Same type as `flake.tests`, because it is the same kind of thing read by the same runner —
  # only the assertion the cells carry differs.
  options.flake.testsError = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.raw);
    default = { };
    description = "Test suites whose cells assert an ERROR: { suite.test = { expr; expectedError; }; }. Read by `nix-unit --flake ./ci#testsError`; deliberately outside `flake.tests`, which the batch asserter quantifies over.";
  };

  config.flake.testsError.link-refusals = {
    # ── THE COMPLETENESS GUARD, BY ITS OWN TEXT ──
    # `b/apps/app` declares a `dbreq` hole and no `wire` entry names it. Reaching every merged
    # requirer rather than only the ones `wire` mentions is the whole point of this guard: a
    # requirer nothing wires is exactly the one a wire-driven walk cannot see, and without the
    # guard `link` returns a manifest that is silently short of an edge.
    test-an-unwired-hole-names-the-aspect-the-facet-and-the-repair = {
      expr = linkManifest { };
      expectedError = {
        type = "ThrownError";
        msg = exactly (unwiredHoleRefusal "b/apps/app" [ "dbreq" ]);
      };
    };

    # ── THE MEMBERSHIP GUARD, BY ITS OWN TEXT ──
    # The filler names a coordinate the merged federation does not carry. The message names the
    # reference AS WRITTEN as well as what it resolved to, so a reader who mistyped an origin sees
    # their own string back rather than only a value they cannot reverse.
    test-a-filler-outside-the-federation-names-the-reference = {
      expr = linkManifest {
        wire."b/apps/app".dbreq = "a/nonexistent";
      };
      expectedError = {
        type = "ThrownError";
        msg = exactly (
          unknownTargetRefusal "wire filler 'a/nonexistent'" (
            genLink.keyRefTargetId (genLink.parseRef "a/nonexistent")
          )
        );
      };
    };
  };
}
