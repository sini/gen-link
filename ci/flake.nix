{
  inputs = {
    gen-harness.url = "github:sini/gen-harness";
    gen-prelude.url = "github:sini/gen-prelude";
    gen-merge.url = "github:sini/gen-merge";
    gen-schema.url = "github:sini/gen-schema";
    gen-algebra.url = "github:sini/gen-algebra";

    # EXACTLY ONE gen-schema node through the whole stack, mirroring the root flake: gen-aspects
    # stamps every aspect and gen-scope's minting entry mints every federation node, so two copies
    # are two content-address formulas for one node. The pair is the current discharge of that
    # invariant; `tests/lock-shape.nix` is what asserts the invariant itself.
    gen-aspects.url = "github:sini/gen-aspects";
    gen-aspects.inputs.gen-schema.follows = "gen-schema";

    gen-scope.url = "github:sini/gen-scope";
    gen-scope.inputs.gen-schema.follows = "gen-schema";
    # ★ THE MINT IS ITS OWN DOOR NOW, AND IT NEEDS THE SAME COLLAPSE. The content-address FORMULA
    # moved out of gen-schema into a dependency-free leaf, so "one gen-schema" no longer implies
    # one encoding: gen-schema, gen-scope and gen-aspects each carry a gen-identity of their own,
    # and two of those are two formulas for one node. The follows pairs below are that property's
    # current discharge, exactly as the gen-schema pairs are for reflection.
    gen-identity.url = "github:sini/gen-identity";
    gen-schema.inputs.gen-identity.follows = "gen-identity";
    gen-scope.inputs.gen-identity.follows = "gen-identity";
    gen-aspects.inputs.gen-identity.follows = "gen-identity";

    # ★ gen-view SUPPLIES THE REFERENCE-RESOLUTION CONSTRUCT AND OPENS NO NEW DOOR ONTO EITHER
    # AUTHORITY. Its lock holds exactly three nodes (root, gen-prelude, gen-graph), so it reaches
    # neither gen-schema nor gen-identity and owes no `follows` pair; `tests/lock-shape.nix`
    # re-measures the counts rather than trusting that.
    #
    # ★★ IT REPLACED gen-resolve HERE, AND THAT CLOSED A DOOR RATHER THAN OPENING ONE. gen-resolve
    # carried a gen-scope of its own which had acquired a gen-schema — a third door onto the
    # reflection authority that neither pair above covered, which `tests/lock-shape.nix` named
    # before it opened and then FAILED on when the bump opened it. That is what an invariant is for
    # as against a one-off inspection at landing; the door is now simply gone.
    gen-view.url = "github:sini/gen-view";
    # nixpkgs is the CI runner's dependency (nix-unit harness, treefmt) and supplies the `lib` the
    # test modules use for assertions + registry construction. The library itself (../lib) is
    # nixpkgs-lib-free (ci/tests/purity.nix enforces this).
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{
      gen-harness,
      gen-prelude,
      gen-merge,
      gen-schema,
      gen-identity,
      gen-algebra,
      gen-aspects,
      gen-scope,
      gen-view,
      ...
    }:
    let
      genMerge = gen-merge.lib;
      aspects = gen-aspects.lib;
      genLink = import ../lib {
        prelude = gen-prelude.lib;
        scope = gen-scope.lib;
        view = gen-view.lib;
        schema = gen-schema.lib;
        algebra = gen-algebra.lib;
        inherit aspects;
      };

      # Build an aspect registry from a keySemantics vocabulary + config modules (mirrors
      # gen-aspects' mkSchemaEval). Returns the evalModuleTree result; read `.config.aspects`.
      mkAspectRegistry =
        {
          keySemantics ? { },
          modules,
        }:
        let
          schema = aspects.mkAspectSchema { inherit keySemantics; };
        in
        genMerge.evalModuleTree {
          modules = [
            { options.schema = schema.schemaOption; }
            (schema.mkAspectModule { })
          ]
          ++ modules;
        };
    in
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-link";
      testModules = ./tests;
      specialArgs = {
        inherit
          genLink
          aspects
          genMerge
          mkAspectRegistry
          ;
        # The harness's own `genPrelude` carries `hasInfix` and nothing else — enough for the
        # purity scan, not enough for `ci/tests/entry.nix`, which hands the root shim every formal
        # it declares so the shim's `fetch`-backed defaults are never forced. It gets gen-link's own
        # gen-prelude, the same instance `genLink` above is built from, so the suites and the
        # subject share one build rather than holding two.
        genPrelude = gen-prelude.lib;
        genView = gen-view.lib;
        genAlgebra = gen-algebra.lib;
        genSchema = gen-schema.lib;
        genIdentity = gen-identity.lib;
        genScope = gen-scope.lib;
      };
      # Cells whose subject is an error MESSAGE cannot live under `testModules`: the batch asserter
      # behind `checks.default` quantifies over `flake.tests` and forces every `expr`
      # unconditionally, so a throwing one crashes that gate instead of failing a cell. They get
      # their own output, read by `nix-unit --flake ./ci#testsError`, and being outside this tree
      # is what keeps that structural rather than conventional.
      extraModules = [
        ./tests-error.nix
      ];
    };
}
