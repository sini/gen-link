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

    # ★ gen-view SUPPLIES THE REFERENCE-RESOLUTION CONSTRUCT AND OPENS NO NEW DOOR. Measured: its
    # lock holds exactly three nodes (root, gen-prelude, gen-graph), so it reaches neither
    # gen-schema nor gen-identity and needs no `follows` line of its own. `ci/tests/lock-shape.nix`
    # re-measures that rather than trusting this comment.
    #
    # ★★ IT REPLACES gen-resolve, WHICH LEAVES IN THE SAME CHANGE. That library's `reference` was
    # this repository's ENTIRE dependence on it — one call site — and after the rewrite a retained
    # `gen-resolve` formal would be a declared dependency the library never reads, which
    # `ci/tests/entry.nix` names as the exact state it exists to catch (it is how the retired `edge`
    # formal survived). Its gen-scope's gen-schema door closes with it.
    gen-view.url = "github:sini/gen-view";

    gen-schema.url = "github:sini/gen-schema";
    gen-algebra.url = "github:sini/gen-algebra";

    gen-scope.url = "github:sini/gen-scope";
    gen-scope.inputs.gen-schema.follows = "gen-schema";

    gen-aspects.url = "github:sini/gen-aspects";
    gen-aspects.inputs.gen-schema.follows = "gen-schema";

    # ★ THE MINT IS ITS OWN DOOR NOW, AND IT NEEDS THE SAME COLLAPSE. The content-address FORMULA
    # moved out of gen-schema into a dependency-free leaf, so "one gen-schema" no longer implies
    # one encoding: gen-schema, gen-scope and gen-aspects each carry a gen-identity of their own,
    # and two of those are two formulas for one node. The follows pairs below are that property's
    # current discharge, exactly as the gen-schema pairs are for reflection.
    gen-identity.url = "github:sini/gen-identity";
    gen-schema.inputs.gen-identity.follows = "gen-identity";
    gen-scope.inputs.gen-identity.follows = "gen-identity";
    gen-aspects.inputs.gen-identity.follows = "gen-identity";
  };

  outputs =
    {
      gen-prelude,
      gen-scope,
      gen-view,
      gen-schema,
      gen-algebra,
      gen-aspects,
      ...
    }:
    {
      lib = import ./lib {
        prelude = gen-prelude.lib;
        scope = gen-scope.lib;
        view = gen-view.lib;
        schema = gen-schema.lib;
        algebra = gen-algebra.lib;
        aspects = gen-aspects.lib;
      };
    };
}
