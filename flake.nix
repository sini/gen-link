{
  description = "gen-link: cross-flake aspect federation over origin-labeled subgraphs";

  # Class B conductor: pure gen siblings, each self-wiring its own deps — except gen-schema, which the
  # follows below collapses to ONE instance. No nixpkgs input — the library (./lib) is nixpkgs-lib-free
  # (checked by ci/tests/purity.nix). nixpkgs is pulled ONLY in ci/ (the nix-unit harness + registry
  # construction).
  #
  # THE INVARIANT THE FOLLOWS SET DISCHARGES: each lock resolves to EXACTLY ONE gen-schema node,
  # counted through root.inputs resolution and never by lock-node name. It is load-bearing rather
  # than hygiene. gen-link reaches the identity authority by two routes — gen-aspects, which stamps
  # every aspect, and gen-scope, whose minting entry mints every federation node — and two instances
  # are two content-address formulas for one node. Followed, both routes are the same formula by
  # lock construction.
  #
  # The pair below is the CURRENT discharge of that invariant and not the invariant itself: a lock
  # gains a gen-schema through whatever input acquires one, and `ci/tests/lock-shape.nix` is what
  # keeps the property asserted when the set of doors changes.
  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";
    gen-edge.url = "github:sini/gen-edge";

    # gen-resolve carries a gen-scope of its own, and that gen-scope now carries a gen-schema — a
    # third door onto the identity authority, which neither entry below covers.
    gen-resolve.url = "github:sini/gen-resolve";
    gen-resolve.inputs.gen-scope.inputs.gen-schema.follows = "gen-schema";

    gen-schema.url = "github:sini/gen-schema";
    gen-algebra.url = "github:sini/gen-algebra";

    gen-scope.url = "github:sini/gen-scope";
    gen-scope.inputs.gen-schema.follows = "gen-schema";

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
