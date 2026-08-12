{
  description = "gen-link: cross-flake aspect federation over origin-labeled subgraphs";

  # Class B conductor: pure gen siblings, each self-wiring its own deps — except gen-schema, which the
  # follows below collapses to ONE instance. No nixpkgs input — the library (./lib) is nixpkgs-lib-free
  # (checked by ci/tests/purity.nix). nixpkgs is pulled ONLY in ci/ (the nix-unit harness + registry
  # construction).
  #
  # The follows is load-bearing, not hygiene: gen-link mints ids by two routes — gen-aspects' `aspectId`
  # (resolved against gen-aspects' OWN gen-schema) and `schema.hashIdentity` (this input) — and then
  # joins them BY ID in lib/link.nix. Two gen-schema instances are two content-address formulas, under
  # which every route-crossing lookup misses and declared holes read unwired. Followed, the two routes
  # are the same formula by lock construction.
  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";
    gen-scope.url = "github:sini/gen-scope";
    gen-resolve.url = "github:sini/gen-resolve";
    gen-edge.url = "github:sini/gen-edge";
    gen-schema.url = "github:sini/gen-schema";
    gen-algebra.url = "github:sini/gen-algebra";

    gen-aspects.url = "github:sini/gen-aspects";
    gen-aspects.inputs.gen-schema.follows = "gen-schema";
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
