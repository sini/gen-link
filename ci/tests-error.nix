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
  aspects,
  mkAspectRegistry,
  ...
}:
let
  fixtures = import ./tests/_fixtures/link.nix {
    inherit
      genLink
      genMerge
      aspects
      mkAspectRegistry
      ;
  };
  inherit (fixtures)
    linkManifest
    unwiredHoleRefusal
    unknownTargetRefusal
    unresolvedRelatumRefusal
    missingKeySemanticsRefusal
    undeclaredHoleRefusal
    ;

  manifestOf = args: (genLink.link args).manifest;

  # The message, pinned to the byte. nixpkgs' metacharacter set is the one the pattern is read under.
  exactly = msg: "^" + lib.escapeRegex msg + "$";

  # ── `rewrite.originStamp`'s DANGLING-INCLUDES REFUSAL ──
  # Same fixture as `ci/tests/rewrite.nix`'s `regDangling`/`normDangling`/`stampedDangling` — an
  # inline includes entry with no key and no keyRef, which gen-aspects' module system synthesizes a
  # key for regardless of what the author wrote ("orphan/includes/0"). That file's cells assert
  # THAT it refuses (`tryEval` — a boolean, and `tryEval` discards the thrown text, same reason as
  # every other guard on this page); this one asserts WHICH entry the message names.
  regDangling = mkAspectRegistry {
    keySemantics.nixos = {
      category = "class";
    };
    modules = [
      {
        config.aspects.orphan = {
          nixos = { };
          includes = [ { } ];
        };
      }
    ];
  };
  normDangling = genLink.normalize regDangling.config.aspects;
  stampedDangling = genLink.originStamp {
    normalized = normDangling;
    origin = [ "x" ];
  };

  # The engine's own text, transcribed rather than composed here (same convention as
  # `unresolvedRelatumRefusal` above) — `lib/rewrite.nix`'s `relabelFn` is where this is specified.
  danglingIncludesRefusal =
    origin: k:
    "gen-link.rewrite: an includes entry in origin '${origin}' names '${k}', which is not a key in this source's registry (check the includes entry naming it, or that a node with this key exists)";
in
{
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
        msg = exactly (unknownTargetRefusal "wire filler 'a/nonexistent'" "a/nonexistent");
      };
    };

    # ── THE VOCABULARY GUARD, BY ITS OWN TEXT ──
    # ★ AND IT IS WHY THIS CELL IS HERE RATHER THAN AS A BOOLEAN. The federation above and this one
    # differ only in whether the requirer's source entry carries `keySemantics`, and BOTH refuse — so
    # a pair of booleans is equally satisfied by a construction that answers the unwired-hole refusal
    # to both. What says the omission was SEEN rather than silently read as "declares no facets" is
    # that the message names the ORIGIN and spells the explicit empty declaration. The cell above,
    # over the same requirer WITH its vocabulary, is the control: it names the aspect and the facet.
    test-a-source-without-keysemantics-names-the-origin-and-the-repair = {
      expr = (genLink.link { sources = fixtures.sourcesMissingKs; }).manifest;
      expectedError = {
        type = "ThrownError";
        msg = exactly (missingKeySemanticsRefusal "b");
      };
    };

    # ── THE WIRE-SITE GUARD, BY ITS OWN TEXT ──
    # A filling naming a facet no source declares. The message names the entry AS WRITTEN and lists
    # the holes that ARE declared, so a misspelling is read beside the name it missed — a boolean
    # cannot tell this refusal from the membership one, and `notAFacet` resolves to a filler that IS
    # in the federation, so the membership guard is not what fires.
    test-a-filling-naming-no-declared-hole-names-the-entry-and-the-declared-holes = {
      expr = (genLink.link fixtures.undeclaredFilling).manifest;
      expectedError = {
        type = "ThrownError";
        msg = exactly (undeclaredHoleRefusal "b/apps/app" "b/apps/app" "notAFacet" [ "dbreq" ]);
      };
    };
  };

  # ── THE ILL-FOUNDED INSTANTIATION, WHICH USED TO MINT IN SILENCE ──
  # Both cases below produced a well-formed `aspect` identity with no throw, no refusal and no
  # diagnostic. Under ADR-0016 ruling 7 a relatum must be a node minted in a STRICTLY EARLIER pass;
  # the first relates a node to itself and the second relates two nodes mutually, and neither has a
  # stratum between them. The class is no longer detected here — it is INEXPRESSIBLE, because the
  # frozen set a relatum resolves against holds strictly earlier passes only and nothing may seed it.
  #
  # ★ THE MESSAGE IS THE REASON THE CELLS ARE HERE RATHER THAN AS BOOLEANS. What the migration buys
  # over the arm that kept content-addresses as vertex names is that the refusal NAMES A REFERENCE A
  # READER CAN READ. Under that arm this same message would name a 64-hex digest and a reader would
  # need a reverse lookup the system does not provide. A boolean cell cannot tell the two apart.
  config.flake.testsError.minting-refusals = {
    test-a-node-filling-its-own-hole-refuses-by-name = {
      expr = manifestOf fixtures.selfFilling;
      expectedError = {
        type = "ThrownError";
        msg = exactly (unresolvedRelatumRefusal "b/apps/app" "dbreq" "aspect" 0);
      };
    };
    # Within a pass there is no order, so the members of a cycle are ordered by their own declared
    # strings rather than by the order the wire was written in — which is what makes the refusal a
    # property of the program instead of of its presentation.
    test-a-filling-cycle-refuses-by-name = {
      expr = manifestOf fixtures.cycle;
      expectedError = {
        type = "ThrownError";
        msg = exactly (unresolvedRelatumRefusal "b/nb" "dbreq" "aspect" 0);
      };
    };
  };

  # ── THE DANGLING INCLUDES ENTRY, BY ITS OWN TEXT ──
  # `ci/tests/rewrite.nix`'s `test-dangling-includes-refuses-by-name` is the boolean half of this
  # claim; this is the half that says WHICH entry the refusal names.
  config.flake.testsError.rewrite-refusals = {
    test-dangling-includes-message-names-the-entry = {
      expr = stampedDangling.graph.vertices;
      expectedError = {
        type = "ThrownError";
        msg = exactly (danglingIncludesRefusal "x" "orphan/includes/0");
      };
    };
  };

  # ── AN ORIGIN THAT IS NOT A LIST OF STRINGS ── (den-hoag-bkdkg)
  # Each aborted inside `concatStringsSep` before the guard (`cannot coerce a set to a string`).
  config.flake.testsError.origin-refusals =
    let
      cell = who: origin: got: {
        expr = genLink.${who} origin;
        expectedError = {
          type = "ThrownError";
          msg = exactly "gen-link.${who}: got ${got}, expected an origin (a list of strings)";
        };
      };
    in
    {
      test-origin-label-set = cell "originLabel" { name = "y"; } "set";
      test-origin-label-list-of-set = cell "originLabel" [ { name = "y"; } ] "list holding a non-string";
      test-render-origin-set = cell "renderOrigin" { name = "y"; } "set";
      test-render-origin-string = cell "renderOrigin" "y" "string";
    };
}
