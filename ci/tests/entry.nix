# THE STANDALONE ENTRY, EXERCISED. `import ../.. { }` is the non-flake path this repository
# documents twice — `AGENTS.md` describes the root entry and its overridable parameters, and points
# a reader at `ci/repl.nix`, which is that import. Every OTHER cell in this suite takes `genLink`
# from `ci/flake.nix`, which builds it with `import ../lib` from ci's own inputs and so never
# evaluates the root shim. That shim has been fixed once and extended once — the sibling-root arity
# repair, then the schema threading whose comment calls the one-instance dataflow load-bearing —
# both in a file no cell could see regress. This is that cell.
#
# One key per sibling the shim CONSTRUCTS and the library REACHES. Each key was verified in
# isolation: break that shim, evaluate that key alone, watch it go red while the others stay green.
# In a whole-cell run the reported key is whichever the evaluator forces first, and `resolve` runs
# the demo end to end, so it reaches the others' siblings too and often reports before them. The
# keys localise a break when read one at a time; they do not promise that the named key is the
# narrowest one.
#   prelude — `originLabel` is `prelude.concatStringsSep` over the origin segments
#   aspects — `parseRef` resolves through `aspects.keyRef`
#   scope   — `disjointUnion`'s `graph` field IS `scope.overlays`, so the field must be forced
#   algebra — `checkCapability` decides through `record.fromAttrs`/`has`/`assertSatisfies`
#   schema  — `checkRefined` delegates to `schema.checkRefinements`; a null refinement type is a
#             benign call that still has to build the library to ask it
#   view    — reached ONLY from a link that reaches a cross-origin include, because `link` binds
#             `resolvedProvides` to `(view.referenceResolution { … }).compute` and gen-scope's
#             evaluator forces that attribute only for a node that has includes. The demo is the
#             smallest fixture in this repository that gets there, and it is already this suite's
#             fixture. ★ THE KEY FORCES A VALUE: `deepSeq` over the demo drives the resolution, so a
#             shim that constructed gen-view but forwarded it wrongly reddens here rather than
#             passing on the formals alone.
#
# ★★ WHAT THIS CELL NO LONGER HAS TO WITNESS, BECAUSE THE MIGRATION REMOVED THE HAZARD RATHER THAN
# GUARDING IT. The predecessor sibling had to be handed this shim's own `scope`, so that one
# evaluator over one authority served both — and this cell could not tell a threaded instance from a
# self-constructed one that happened to work, which was a stated residual exposure. gen-view takes
# its query AUTHORITY as an injected field: `lib/link.nix` hands it the very `scope` the library
# holds, there is no second evaluator for it to construct, and a threading that could be silently
# undone no longer exists. The shim self-constructs gen-view the way it self-constructs `aspects`.
#
# THE KEY SET IS THE SIBLING SET, and holding that an identity is what keeps this cell's coverage
# total. The shim constructs exactly the siblings `../lib` reads, so every sibling it constructs has
# a key here and a reader in the library. A declared dependency the library never read could not be
# given a key — a cell cannot force what nothing reaches — so it would sit outside this cell's reach
# while looking, from the formals alone, exactly like the ones inside it. That is how the retired
# `edge` formal survived: the shim built it, `../lib` required it, and no key could witness either.
#
# WHY THE KEYS FORCE VALUES. Each key is a positive assertion that the shim constructs its sibling,
# and forcing is how a construction is observed. The negative forms all pass while broken: an arity
# abort is an evaluator error `(builtins.tryEval …).success` does not contain, and `deepSeq` or
# `attrNames` over the surface never enter the lambdas where the siblings are reached. Forcing to
# WHNF is not enough either — `builtins.isAttrs (disjointUnion [ ])` stays green with gen-scope
# broken, because the abort lives one field deeper; that is why the scope key reads `.graph`.
#
# A broken shim fails both instruments. `nix flake check` — the merge gate — reaches these
# assertions through `checks.default` and fails on a wrong value as well as on an abort. `nix-unit`
# isolates the break to one poisoned cell, reported ☢️ with a non-zero exit and NO red ❌, so a
# reading of THAT instrument which tallies only ❌ scores the break green.
{
  genMerge,
  aspects,
  lib,
  ...
}:
let
  # ★ ONE binding, read by BOTH cells. Duplicating the literal makes the control guard its own copy
  # and nothing else — measured: main copy broken ⇒ 2/2 exit 0 on a tree carrying a real member.
  needle = ''}/lib"[[:space:]]*\{'';

  # The same construction `ci/tests/purity.nix` uses, over the same file, for the same stated reason.
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  entry = import ../.. { };

  demo = import ../../examples/demo/demo.nix {
    genLink = entry;
    inherit aspects;
    merge = genMerge;
  };
in
{
  flake.tests.entry.test-standalone-entry-constructs-its-siblings = {
    expr = {
      prelude = builtins.isString (
        entry.originLabel [
          "a"
          "b"
        ]
      );
      aspects = builtins.isAttrs (entry.parseRef "a/apps/media/pg");
      scope = builtins.isAttrs (entry.disjointUnion [ ]).graph;
      algebra = builtins.isAttrs (
        entry.checkCapability {
          edgeName = "e";
          provides = [ "read" ];
          requires = [ "read" ];
        }
      );
      schema = builtins.typeOf (
        entry.checkRefined {
          edgeName = "e";
          refinedType = null;
          value = 1;
        }
      );
      view = builtins.deepSeq demo "linked";
    };
    expected = {
      prelude = true;
      aspects = true;
      scope = true;
      algebra = true;
      schema = "int";
      view = "linked";
    };
  };

  # ★ THE FOUR CELLS ABOVE CANNOT SEE THIS CLASS, and the reason is the property that makes them
  # hermetic: they supply every dependency formal explicitly, so the shim's `fetch`-backed DEFAULTS —
  # which is where the divergence lives — are never forced. Forcing them would put `builtins.fetchTree`
  # inside the suite. This cell reads the CONSTRUCTION instead of the outcome, which is strictly wider:
  # it also catches the member that never throws (a defaulted formal on the far side turns the loud arm
  # of the class silent) and the member that has not yet drifted.
  #
  # ★★ COMMENTS ARE STRIPPED FIRST, AND THAT IS LOAD-BEARING RATHER THAN TIDY. `ci/tests/purity.nix`
  # states the same property for the same reason and over this same file (`stripComments (builtins.readFile
  # ../../default.nix)`): the house convention for a FIXED member is a comment explaining why not `/lib`,
  # and a raw scan reds on that comment while the file is correct. MEASURED, in-suite, on a tree whose
  # member had just been fixed — with a comment PLANTED in the house idiom, because no live site reds
  # today: every existing such comment happens to write `` `./lib` `` (relative, uninterpolated), and
  # raw ≡ stripped across all 14 domain files at HEAD. The strip is PROPHYLACTIC, and that is the
  # point — it stops the next correctly-written comment from reddening a correct file.
  #
  # ★ `[[:space:]]*` spans the newline a formatter may put between `/lib"` and `{` — measured: a
  # line-anchored form misses exactly that.
  #
  # ★★ THE NEEDLE IS BOUND ONCE AND BOTH CELLS READ THAT BINDING. Two literals spelled the same are
  # TWO PREDICATES, and the control would then guard only its own copy: MEASURED — with the needle
  # duplicated, breaking the MAIN copy by one character gave `2/2 successful, exit 0` over a tree
  # carrying a real member, with the control still ✅ in the same run. That is §1.5's class — a second
  # signature nothing compares against the first — committed by the instrument built to detect it.
  # With the shared binding the same one-character break REDS THE CONTROL.
  #
  # ★ A bare `.../lib` with NO argument set is EXCLUDED, and the exclusion is a claim about the FAR SIDE
  # AT ITS PIN rather than about this file: it holds only while the target's `lib` is a value. All
  # nineteen such sites in this domain reach gen-prelude / gen-identity / gen-algebra, each measured
  # `"set"` 2026-08-29. It is NOT a property of the spelling — `den-hoag-jhsb` measured
  # `select ? import "${fetch "gen-select"}/lib"` in gen-pipe yielding a LAMBDA (gen-select's `lib` takes
  # `{ algebra }`), a silent member this predicate does not count — and this cell cannot observe its own
  # premise going false. See §4.4.
  flake.tests.entry.test-no-dependency-is-built-past-its-own-entry =
    let
      parts = builtins.split needle (stripComments (builtins.readFile ../../default.nix));
    in
    {
      # ★ THE ASSERTION IS ON THE COUNT. `reaches` is a diagnostic so a failure names the dependency,
      # but it is derived by a second match that a non-`fetch` spelling defeats — asserting on names
      # alone would read `[ ]` on a real member and pass.
      expr = {
        count = builtins.length (builtins.filter builtins.isList parts);
        reaches = map builtins.head (
          builtins.filter (m: m != null) (
            map (p: builtins.match ''.*fetch "(gen-[a-z-]+)"$'' p) (builtins.filter builtins.isString parts)
          )
        );
      };
      expected = {
        count = 0;
        reaches = [ ];
      };
    };

  # ★★ THE DETECTOR IS SHOWN ABLE TO FIRE, IN THE SAME RUN, ON THE SAME PREDICATE — `purity.nix`'s
  # standing rule and `den-hoag-e421`'s landed remedy. Without it, `count = 0` is equally consistent
  # with a needle that cannot match: MEASURED — one character changed in the needle reads
  # `{ count = 0; reaches = [ ]; }` on a file carrying three real members, i.e. byte-identical to this
  # cell's own `expected`. The planted member is REFLOWED, so it also pins the `[[:space:]]*` span.
  flake.tests.entry.test-control-the-entry-shape-check-discriminates = {
    expr = builtins.length (
      builtins.filter builtins.isList (
        builtins.split needle (stripComments ''
          {
            graph ? import "''${fetch "gen-graph"}/lib"
              { inherit prelude; },
          }: null
        '')
      )
    );
    expected = 1;
  };
}
