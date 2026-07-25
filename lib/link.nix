# The `link` API — the single entry point (design §Federation mechanism). A pure function that stores
# nothing. It owns only the SEQUENCING plus origin / union / manifest; every computation is delegated:
#   1. normalize + origin-rewrite each source          (normalize + rewrite; rides gen-scope gmap)
#   2. disjoint union                                   (union; gen-scope overlay)
#   3. bind holes (instantiation identity)              (wireLib; gen-schema hashIdentity)
#   4. resolve cross-origin references over merged graph AS scope (gen-scope buildNodes/eval + gen-resolve reference)
#   5. type-check each active cross-origin (wired) edge (contract; gen-algebra / gen-schema)
#   6. record the manifest                              (manifest)
# The importing flake joins as a source too (origin [] surfaced as `self`), so `self/*` resolves.
{
  prelude,
  scope,
  resolve,
  identity,
  ref,
  normalize,
  rewrite,
  union,
  facets,
  contract,
  manifest,
  wireLib,
}:
let
  refId = r: identity.keyRefTargetId (ref.parseRef r);

  link =
    {
      sources,
      wire ? { },
    }:
    let
      # ── steps 1+2: normalize + origin-rewrite + disjoint union ──────────────────────────────────
      stamped = map (
        s:
        rewrite.originStamp {
          normalized = normalize.normalize s.registry;
          origin = s.origin or [ ];
          alias = s.alias or { };
        }
      ) sources;
      merged = union.disjointUnion stamped; # { graph; idToNode }

      # per-source keySemantics keyed by origin label (for facet reads at the wire type-check).
      ksByOrigin = prelude.listToAttrs (
        map (s: {
          name = ref.renderOrigin (s.origin or [ ]);
          value = s.keySemantics or { };
        }) sources
      );
      ksOf = origin: ksByOrigin.${ref.renderOrigin origin} or { };

      entryOf =
        id: what:
        merged.idToNode.${id}
          or (throw "gen-link.link: ${what} resolves to id '${id}' which is not in the federation (check origin/path, or add its source)");

      # ── step 5 (per wired edge) + step 3: type-check then bind holes ─────────────────────────────
      bindOne =
        requirerRef: fillings:
        let
          rEntry = entryOf (refId requirerRef) "wire target '${requirerRef}'";
          rKs = ksOf rEntry.origin;
          holeFillings = prelude.mapAttrs (_facet: filler: refId filler) fillings;
          # discharge each filled facet contract (step 5).
          typed = prelude.mapAttrsToList (
            facet: filler:
            let
              fEntry = entryOf (refId filler) "wire filler '${filler}'";
              edgeName = "${requirerRef}#${facet} <- ${filler}";
            in
            if facets.contractOf rKs facet == "refined" then
              contract.checkRefined {
                inherit edgeName;
                # A refined facet TYPES the edge with a gen-schema refined TYPE. gen-schema
                # `checkRefinements` reads `type.__schema.refinements`, so it MUST be handed a proper
                # refined type (`genSchema.refined <base> <refinements>`), NOT a raw refinements list —
                # a raw list carries no `__schema`, and the check silently no-ops (blind). The source
                # declares the facet's contract as a real refined type; gen-link reads THAT.
                refinedType =
                  rKs.${facet}.refinedType
                    or (throw "gen-link.link: facet '${facet}' declared refined but carries no `refinedType` (a genSchema.refined <base> <refinements> type)");
                value = fEntry.node;
              }
            else
              contract.checkCapability {
                inherit edgeName;
                provides = facets.providesOf (ksOf fEntry.origin) fEntry.node;
                requires = facets.requiresOf rEntry.node facet;
              }
          ) fillings;
        in
        # deepSeq forces every contract check to RUN (its throws fire) before the node is bound.
        builtins.deepSeq typed (
          wireLib.bindNode {
            inherit (rEntry) origin node;
            ks = rKs;
            inherit holeFillings;
          }
        );
      boundNodes = prelude.mapAttrsToList bindOne wire;

      # ── step 4: resolve cross-origin references over the merged graph AS the gen-scope scope ──────
      # importIndex: each node id -> the ids it includes (from the merged graph edges). Keys are IDS.
      importIndex = prelude.foldl' (
        acc: e: acc // { ${e.from} = (acc.${e.from} or [ ]) ++ [ e.to ]; }
      ) { } merged.graph.edges;
      roots = scope.buildNodes {
        importGraph = merged.graph;
        # each node's decls carry its capability PROVIDES so the forward query resolves a requirer
        # (which provides nothing => local null) THROUGH its include edge to the provider.
        decls = prelude.mapAttrs (_id: en: {
          inherit (en) origin;
          key = en.node.key;
          provided = facets.providesOf (ksOf en.origin) en.node;
        }) merged.idToNode;
      };
      scopeSelf = scope.eval {
        inherit roots;
        attributes = {
          children = _self: _id: { };
          imports = _self: id: importIndex.${id} or [ ];
          # gen-resolve reference (forward `includes` nearest-binding — Hedin 2000): resolves a node's
          # nearest cross-origin PROVIDER's capability tags. The requirer provides nothing (local null),
          # so resolution walks the include edge to the provider. A stubbed `reference` (compute = _: _:
          # null) makes `resolved` null, which the link/oracle assertions catch — gen-resolve is genuinely
          # load-bearing.
          resolvedProvides =
            (resolve.reference {
              name = "resolvedProvides";
              select =
                n:
                let
                  p = n.decls.provided or [ ];
                in
                if p == [ ] then null else p;
              target = "includes";
            }).compute;
        };
        parseParent = _id: null;
      };
      # per-requirer resolution result (keyed by the requirer's node id) — surfaced in the return so it
      # is observable/assertable (decision 4). Only nodes WITH includes are queried.
      resolved = prelude.listToAttrs (
        map (fromId: {
          name = fromId;
          value = scopeSelf.get fromId "resolvedProvides";
        }) (builtins.attrNames importIndex)
      );

      # cross-origin edges: reachability is validated by `entryOf` (throws named if a target is absent).
      crossOriginEdges = builtins.filter (
        e: (entryOf e.from "edge source").origin != (entryOf e.to "include target").origin
      ) merged.graph.edges;

      # ── step 6: the manifest ──────────────────────────────────────────────────────────────────────
      manifestEntries = manifest.order (
        (map (
          e:
          manifest.entry {
            kind = "includes";
            inherit (e) from to;
          }
        ) crossOriginEdges)
        ++ prelude.concatMap (
          bn:
          prelude.mapAttrsToList (
            facet: fid:
            manifest.entry {
              kind = "hole";
              from = bn.id;
              to = fid;
              via = facet;
            }
          ) bn.holeFillings
        ) boundNodes
      );
    in
    {
      graph = merged.graph;
      manifest = manifestEntries;
      nodes = merged.idToNode;
      bound = boundNodes;
      inherit resolved;
    };
in
{
  inherit link;
}
