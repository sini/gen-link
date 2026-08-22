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
  ...
}:
let
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
}
