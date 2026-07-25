{
  description = "gen-link: cross-flake aspect federation over origin-labeled subgraphs";

  # Class B conductor: pure gen siblings, each self-wiring its own deps. No nixpkgs input — the
  # library (./lib) is nixpkgs-lib-free (checked by ci/tests/purity.nix). nixpkgs is pulled ONLY
  # in ci/ (the nix-unit harness + registry construction).
  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";
    gen-scope.url = "github:sini/gen-scope";
    gen-resolve.url = "github:sini/gen-resolve";
    gen-edge.url = "github:sini/gen-edge";
    gen-schema.url = "github:sini/gen-schema";
    gen-algebra.url = "github:sini/gen-algebra";
    gen-aspects.url = "github:sini/gen-aspects";
  };

  outputs =
    {
      gen-prelude,
      gen-scope,
      gen-resolve,
      gen-edge,
      gen-schema,
      gen-algebra,
      gen-aspects,
      ...
    }:
    {
      lib = import ./lib {
        prelude = gen-prelude.lib;
        scope = gen-scope.lib;
        resolve = gen-resolve.lib;
        edge = gen-edge.lib;
        schema = gen-schema.lib;
        algebra = gen-algebra.lib;
        aspects = gen-aspects.lib;
      };
    };
}
