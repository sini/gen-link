# THE conductor oracle (design §Testing). Exercises gen-aspects (key/keyRef), gen-scope (overlay/gmap
# + buildRoots/eval + mintStrata), gen-view (referenceResolution), gen-algebra (assertSatisfies), gen-schema
# (hashIdentity, reached THROUGH the minting entry), gen-view (viewRelation) in ONE chain. A stub in
# any breaks it.
{
  genLink,
  genView,
  genMerge,
  genSchema,
  genIdentity,
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

  # the bound requirer (B/app), whose identity folds the wired hole.
  appBound = builtins.head (builtins.filter (b: b.node.key == "apps/app") result.bound);
  # B/app's identifier — the vertex name, and the key `result.resolved` is indexed by.
  appIdentifier = "b/apps/app";
  pgIdentifier = "a/apps/media/pg";

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

  # step 4: materialize the bound node's class content through gen-view (a minimal scope graph).
  #
  # The content enters as an AUTHORED DATUM of the graph's data component. `data(G)` is a component
  # of the graph value rather than an accessor, so what competes is exactly what an author wrote
  # there and no step of the walk can put a datum where a later step reads one. The carrier is the
  # linear one, under which a datum is one segment of the folded list — so the bound node's class
  # content is one contribution and the channel's value is the one-element list holding it.
  appNixos = appBound.node.nixos;

  # L is non-empty by law (an alphabet with no letters admits no path), and `parent` is the letter
  # this graph declares and leaves empty: one position, no incidence, so the only path from the root
  # is the empty one and the datum is reached at distance 0.
  viewLabels = genView.edgeLabels { letters = [ "parent" ]; };
  viewAdmission = genView.labelWellFormedness {
    alphabet = viewLabels;
    expression = "parent*";
  };
  viewOrder = genView.labelOrder {
    alphabet = viewLabels;
    layers = [ [ "parent" ] ];
    endOfPath = -1;
  };
  appGraph = genView.scopeGraph {
    carrier = genView.carrier {
      labels = viewLabels;
      relations = genView.relations { names = [ "content" ]; };
      # Λ is empty: this graph holds no reified bindings, which is the ordinary case and lawful
      # where an empty R would not be.
      relatumLabels = genView.relatumLabels { names = [ ]; };
      labelWellFormedness = viewAdmission;
      labelOrder = viewOrder;
      dataOrder = genView.dataOrder {
        channel = "nixos";
        keyOf = c: c.scope;
      };
    };
    scopes = [ "app" ];
    edges.parent = _: [ ];
    data = [
      {
        scope = "app";
        relation = "content";
        datum = [ appNixos ];
      }
    ];
  };
  cfg = genView.viewRelation {
    definition = genView.compositions.channel {
      channel = "nixos";
      relation = "content";
      root = "app";
      direction = "outbound";
      admission = viewAdmission;
      order = viewOrder;
      wellFormed = _: true;
      tieSet = genView.tieSets.union;
      empty = [ ];
      combine = genView.combines.listAppend;
      # No contribution here can collapse against another, and the arm is declared rather than
      # defaulted because absence would be a decision nobody made.
      dedup = genView.dedups.none;
    };
    graph = appGraph;
    # No boundary marks. Written down rather than defaulted: this is the axis where silence must
    # never read as access.
    marks = _: [ ];
  };
  # Placement is a family BESIDE the declaration, never a field of it — which cell the result lands
  # in is a placement fact.
  appTarget = genView.placement.targets.root {
    scope = "app";
    channel = "nixos";
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
  # the reference-resolution construct is load-bearing: B/app's cross-origin include resolves to A/pg's
  # capability tags. A stub `reference` (compute = _: _: null) => null => this fails.
  flake.tests.conductor-oracle.test-reference-resolution-resolves-provider = {
    expr = result.resolved.${appIdentifier};
    expected = [
      "read"
      "write"
    ];
  };
  # Instantiation identity end-to-end, RECONSTRUCTED rather than compared to itself. ADR-0016
  # ruling 4 gives the binding case whole — a kind whose identity keys are its relatum labels and
  # whose values are the relata's IDENTITIES — and the minting entry adds the node's own identifier
  # under a reserved label. Rebuilding the digest from those facts through the same authority says
  # the wired node's identity really is that function of the filler, and it fails if the relatum's
  # value were its identifier, if the label carried a prefix, or if a second gen-schema instance
  # were computing either end.
  #
  # ★★ THE KIND COMES FROM THE MANIFEST ROW, WHICH IS WHAT MAKES THAT FIELD MEASURED RATHER THAN
  # DECLARED. The row's `fromKind` is fed straight into the authority as the minting kind, so a row
  # carrying a kind the node was not minted under produces a different digest and this cell fails.
  # It also exhibits the property the field exists for: the identity REBUILDS from a row plus the
  # relatum's identity, with nothing read out of band — which is what the rows have to support once
  # a federation mixes kinds, since the identity that carries the kind as its tag never serializes.
  flake.tests.conductor-oracle.test-identity-rebuilds-from-the-manifest-row = {
    expr = appBound.identity;
    expected =
      let
        row = builtins.head (builtins.filter (e: e.kind == "hole") result.manifest);
      in
      genIdentity.hashIdentity row.fromKind
        [
          "identifier"
          row.via
        ]
        (
          k:
          {
            identifier = row.from;
            ${row.via} = result.nodes.${row.to}.identity;
          }
          .${k}
        );
  };
  # 4: the linked node's class content materialized through gen-view. Three facts, each the
  # counterpart of one conjunct the released materialization was asserted by: WHICH cell the result
  # lands in, WHERE the contribution was gathered, and WHAT the channel folded to. `writesOf` is the
  # cell arm and it cross-checks the target's channel against the view relation's own name, so a
  # target naming a cell this result does not produce is refused rather than compared.
  flake.tests.conductor-oracle.test-materialize-through-gen-view = {
    expr = {
      cell = genView.writesOf {
        relation = cfg;
        target = appTarget;
        mode = "merge";
      };
      scopes = map (c: c.scope) cfg.contributions;
      value = cfg.value;
    };
    expected = {
      cell = [ "app/nixos@output" ];
      scopes = [ "app" ];
      value = [ appNixos ];
    };
  };
}
