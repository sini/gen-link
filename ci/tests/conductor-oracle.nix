# THE conductor oracle (design §Testing). Exercises gen-aspects (aspectId), gen-scope (overlay/gmap +
# buildNodes/eval), gen-resolve (reference), gen-algebra (assertSatisfies), gen-schema (hashIdentity),
# gen-edge (materialize) in ONE chain. A stub in any breaks it.
{
  genLink,
  genEdge,
  genMerge,
  aspects,
  mkAspectRegistry,
  ...
}:
let
  facetOpt = genMerge.mkOption {
    type = genMerge.types.raw;
    default = null;
  };
  ks = {
    nixos = {
      category = "class";
    };
    dbcap = {
      category = "facet";
      contract = "capability";
      option = facetOpt;
    };
    dbreq = {
      category = "facet";
      contract = "capability";
      option = facetOpt;
    };
  };
  regA = mkAspectRegistry {
    keySemantics = ks;
    modules = [
      {
        config.aspects.apps.media.pg = {
          nixos.networking.hostName = "pg-a";
          dbcap = {
            provides = [
              "read"
              "write"
            ];
          };
        };
      }
    ];
  };
  regB = mkAspectRegistry {
    keySemantics = ks;
    modules = [
      {
        config.aspects.apps = {
          media.pg.nixos.networking.hostName = "pg-b"; # SAME path as A
          app = {
            nixos.services.app.enable = true;
            dbreq = {
              requires = [ "read" ];
            };
            includes = [ (aspects.keyRef "a/apps/media/pg") ];
          };
        };
      }
    ];
  };
  mkSources = {
    sources = [
      {
        registry = regA.config.aspects;
        keySemantics = ks;
        origin = [ "a" ];
      }
      {
        registry = regB.config.aspects;
        keySemantics = ks;
        origin = [ "b" ];
      }
    ];
  };
  result = genLink.link (mkSources // { wire."b/apps/app".dbreq = "a/apps/media/pg"; });

  # step 2: the two same-path pg nodes are distinct.
  pgIds = builtins.filter (id: result.nodes.${id}.node.key == "apps/media/pg") (
    builtins.attrNames result.nodes
  );

  # the bound requirer (B/app), whose id folds the wired hole.
  appBound = builtins.head (builtins.filter (b: b.node.key == "apps/app") result.bound);
  # B/app's (holeless) graph node id — the key `result.resolved` is indexed by.
  appNodeId = genLink.nodeId [ "b" ] regB.config.aspects.apps.app;

  # step 3 negative: an unsatisfiable capability wire must throw. Project `.manifest` so tryEval FORCES
  # the lazy bound/type-check (the return record reaches WHNF without it — mirrors Task 9's `badWire`).
  bad = builtins.tryEval (
    (genLink.link (
      mkSources
      // {
        wire."b/apps/app".dbreq = "b/apps/media/pg"; # B/pg provides NOTHING
      }
    )).manifest
  );

  # step 4: materialize the bound node's class content through gen-edge (a minimal accessor graph).
  appNixos = appBound.node.nixos;
  edgeGraph = {
    nodes = [ "app" ];
    childrenOf = _: [ ];
    parentOf = _: null;
    isolatedAt = _: false;
    channelsOf = id: if id == "app" then [ "nixos" ] else [ ];
    edgesAt = _: [ ];
    nameOf = id: {
      opaque = id;
    };
    contentsOf = _id: _ch: [ ];
  };
  cfg = genEdge.materialize {
    edges = [
      (genEdge.edge {
        source = genEdge.sources.value appNixos;
        target = genEdge.targets.root {
          root = "app";
          class = "nixos";
        };
        mode = "merge";
      })
    ];
    projection = genEdge.project {
      graph = edgeGraph;
      root = "app";
    };
  };
in
{
  # 1-2: origin-union -> distinct origin-qualified ids for the same path.
  flake.tests.conductor-oracle.test-distinct-origin-ids = {
    expr = builtins.length pgIds == 2 && (builtins.elemAt pgIds 0) != (builtins.elemAt pgIds 1);
    expected = true;
  };
  # 3: the wired capability edge type-checked (link evaluated) — and the unsatisfiable variant throws.
  flake.tests.conductor-oracle.test-typed-edge-holds = {
    expr = builtins.length (builtins.filter (e: e.kind == "hole") result.manifest);
    expected = 1;
  };
  flake.tests.conductor-oracle.test-unsatisfiable-edge-throws = {
    expr = bad.success;
    expected = false;
  };
  # gen-resolve load-bearing: B/app's cross-origin include resolves (via `reference`) to A/pg's
  # capability tags. A stub `reference` (compute = _: _: null) => null => this fails.
  flake.tests.conductor-oracle.test-gen-resolve-resolves-provider = {
    expr = result.resolved.${appNodeId};
    expected = [
      "read"
      "write"
    ];
  };
  # instantiation identity end-to-end: the bound id folds the hole.
  flake.tests.conductor-oracle.test-instantiation-folds-hole = {
    expr = appBound.id == genLink.nodeId [ "b" ] appBound.node;
    expected = false;
  };
  # 4: the linked node's class content materialized through gen-edge.
  flake.tests.conductor-oracle.test-materialize-through-gen-edge = {
    expr = (cfg ? app) && (cfg.app ? nixos) && builtins.length cfg.app.nixos == 1;
    expected = true;
  };
}
