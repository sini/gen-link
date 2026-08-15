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

    gen-resolve.url = "github:sini/gen-resolve";
    gen-edge.url = "github:sini/gen-edge";
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
      gen-algebra,
      gen-aspects,
      gen-scope,
      gen-resolve,
      gen-edge,
      ...
    }:
    let
      genMerge = gen-merge.lib;
      aspects = gen-aspects.lib;
      genLink = import ../lib {
        prelude = gen-prelude.lib;
        scope = gen-scope.lib;
        resolve = gen-resolve.lib;
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
        genEdge = gen-edge.lib;
        genAlgebra = gen-algebra.lib;
        genSchema = gen-schema.lib;
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
