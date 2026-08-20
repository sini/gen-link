# The `link` API — the single entry point (design §Federation mechanism). A pure function that stores
# nothing. It owns only the SEQUENCING plus origin / union / manifest; every computation is delegated:
#   1. normalize + origin-rewrite each source          (normalize + rewrite; rides gen-scope gmap)
#   2. disjoint union                                   (union; gen-scope overlay)
#   3. type-check each wired facet, then MINT the whole federation in staged passes (contract; scope)
#   4. resolve cross-origin references over merged graph AS scope (gen-scope buildNodes/eval + gen-resolve reference)
#   5. record the manifest                              (manifest)
# The importing flake joins as a source too (origin [] surfaced as `self`), so `self/*` resolves.
#
# ── WHY EVERY NODE IS AN EMITTER, AND NOT ONLY THE WIRED ONES ──
# The minting entry resolves a relatum only against the FROZEN SET, which holds what strictly
# earlier passes settled; a caller may not seed it, on the ground that a forgeable frozen set is a
# rule authors must obey rather than a construction. So a filler must be an emitter — and since any
# federation node may be named as a filler, EVERY node is one. There is no smaller migration: a
# scheme minting only the wired nodes would need the rest already in the frozen set, and the only
# door into that set is emission.
#
# ★★ THE CONSEQUENCE IS THAT THE VERTEX NAME IS NO LONGER A CONTENT-ADDRESS. This library used to
# key its graph by `aspectId`'s digest and hand a SECOND digest to a wired node, so a node had two
# values of one type and no name for the difference — `resolved` keyed one way and the bound record
# the other, a trap this file used to ship. ADR-0016 ruling 5 separates IDENTIFIER (the vertex name,
# the edge endpoint, what an emitter writes) from IDENTITY (the derived content-address), and the
# separation is what the migration buys: the identifier is the federation reference, the identity is
# minted once per node by the ONE authority, and a diagnostic names a reference a reader can read.
{
  prelude,
  scope,
  resolve,
  ref,
  normalize,
  rewrite,
  union,
  facets,
  contract,
  manifest,
}:
let
  identifierOf = r: ref.refIdentifier (ref.parseRef r);

  # The minting kind of every federation node. One kind, because the identity key set is the node's
  # own identifier plus its relatum labels and nothing here relates two different sorts of thing.
  aspectKind = "aspect";

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
      merged = union.disjointUnion stamped; # { graph; idToNode } — both keyed by IDENTIFIER

      # per-source keySemantics keyed by origin label (for facet reads at the wire type-check, and
      # handed to the minting entry as its kind stratum).
      ksByOrigin = prelude.listToAttrs (
        map (s: {
          name = ref.renderOrigin (s.origin or [ ]);
          value = s.keySemantics or { };
        }) sources
      );
      ksOf = origin: ksByOrigin.${ref.renderOrigin origin} or { };

      entryOf =
        identifier: what:
        merged.idToNode.${identifier}
          or (throw "gen-link.link: ${what} names '${identifier}', which is not in the federation (check origin/path, or add its source)");

      # ── step 3a: type-check each wired facet, and read off the relata it contributes ────────────
      wireOf =
        requirerRef: fillings:
        let
          identifier = identifierOf requirerRef;
          rEntry = entryOf identifier "wire target '${requirerRef}'";
          rKs = ksOf rEntry.origin;
          # A hole filling contributes a relatum whose LABEL is the facet name, unprefixed, and whose
          # VALUE is the filler's identifier. ADR-0024 as amended makes the string that keys the
          # identity the same string an incident edge carries, so choosing a label is choosing a
          # traversal token — and `hole:` names the mechanism rather than the relation.
          relata = prelude.mapAttrs (_facet: filler: identifierOf filler) fillings;
          # discharge each filled facet contract.
          typed = prelude.mapAttrsToList (
            facet: filler:
            let
              fEntry = entryOf (identifierOf filler) "wire filler '${filler}'";
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
        # deepSeq forces every contract check to RUN (its throws fire) before the record is read.
        builtins.deepSeq typed {
          inherit identifier relata;
          inherit (rEntry) origin node;
          site = "wire entry '${requirerRef}'";
        };
      wired = prelude.mapAttrsToList wireOf wire;

      # ── step 3b: the pass, DERIVED from the wire graph before any emitter exists ────────────────
      # A node with no fillings takes pass 0; a node all of whose fillers are assigned takes one more
      # than the greatest of theirs. The assignment is a pure function of { sources, wire }, so it is
      # invariant under presentation order BY CONSTRUCTION rather than by an author's discipline —
      # which is more than a user-declared index could offer, since only the wire graph determines
      # the answer and restating a derivable fact is how the two copies drift.
      #
      # ★★ THE BOUND IS NOT DEFENSIVE PROGRAMMING. A wire cycle has no finite depth, so an unbounded
      # fixpoint over one would diverge — and Nix's call-depth abort is not contained by `tryEval`.
      # Today's behaviour for a cycle is a SILENT well-formed identity; replacing a silent wrong
      # answer with an uncatchable hang is not an improvement. A node still unassigned when the bound
      # is reached is emitted at pass 0, where its relatum cannot resolve and the engine refuses it
      # BY NAME. This library detects no cycle: ADR-0033's `inexpressible, never detected` is
      # honoured at the level that owns it.
      fillersOf = prelude.foldl' (
        acc: w: acc // { ${w.identifier} = (acc.${w.identifier} or [ ]) ++ (builtins.attrValues w.relata); }
      ) { } wired;
      identifiers = builtins.attrNames merged.idToNode;
      assignPass =
        assigned:
        prelude.foldl' (
          acc: id:
          let
            fillers = fillersOf.${id} or [ ];
          in
          if acc ? ${id} then
            acc
          else if !(builtins.all (f: acc ? ${f}) fillers) then
            acc
          else if fillers == [ ] then
            acc // { ${id} = 0; }
          else
            acc
            // {
              ${id} = 1 + prelude.foldl' (m: f: if acc.${f} > m then acc.${f} else m) 0 fillers;
            }
        ) assigned identifiers;
      passes = prelude.iterateBounded (a: builtins.deepSeq a a) assignPass { } identifiers;
      passOf = id: passes.${id} or 0;

      # ── step 3c: the mint ───────────────────────────────────────────────────────────────────────
      # One emitter per wire entry, plus one per merged node no wire entry names. Two wire entries
      # resolving to ONE identifier therefore arrive as two emitters of one node, which the engine's
      # own merge rule collapses when they agree and refuses BY NAME when they do not — naming both
      # wire keys. Nothing here checks for that collision; it is the engine's rule doing the work.
      wiredIdentifiers = builtins.listToAttrs (
        map (w: {
          name = w.identifier;
          value = true;
        }) wired
      );
      mkEmitter = e: {
        inherit (e) identifier relata site;
        kind = aspectKind;
        pass = passOf e.identifier;
        # The federation's node values stay this library's own. The entry deep-forces its result, so
        # carrying aspect content through it would force every option of every node — a cost that
        # buys nothing here, because nothing across the seam reads a node.
        content = { };
      };
      emitters =
        map mkEmitter wired
        ++ map (
          id:
          mkEmitter {
            identifier = id;
            relata = { };
            site = "source '${ref.renderOrigin merged.idToNode.${id}.origin}'";
          }
        ) (builtins.filter (id: !(wiredIdentifiers ? ${id})) identifiers);

      minted = scope.mintStrata {
        inherit emitters;
        # The kind stratum, as an already-evaluated value. The entry forces it to weak head normal
        # form and never reads it; `ksByOrigin` is a value by the time this runs, so the property the
        # argument boundary exists for holds.
        kinds = ksByOrigin;
      };

      # ── unfilled-hole completeness guard over the MERGED requirer set (decision 7) ────────────────
      # `wireOf` only reaches requirers that `wire` NAMES, so a merged requirer carrying a `requires`
      # facet with NO `wire` entry would land unbound and `link` would SUCCEED silently. Drive
      # `facets.holesOf` over EVERY merged node and demand each declared hole is covered by a `wire`
      # entry for that node's reference.
      wiredFacetsById = prelude.listToAttrs (
        map (w: {
          name = w.identifier;
          value = builtins.attrNames w.relata;
        }) wired
      );
      unwiredHoleGuard = prelude.mapAttrsToList (
        identifier: en:
        let
          holes = facets.holesOf (ksOf en.origin) en.node;
          wiredFacets = wiredFacetsById.${identifier} or [ ];
          unfilled = builtins.filter (h: !(builtins.elem h wiredFacets)) holes;
        in
        if unfilled == [ ] then
          null
        else
          throw "gen-link.link: aspect '${identifier}' has unwired required facet(s): ${builtins.concatStringsSep ", " unfilled}. Wire each via `wire.\"${identifier}\".<facet> = <provider-ref>`."
      ) merged.idToNode;

      # ── step 4: resolve cross-origin references over the merged graph AS the gen-scope scope ──────
      # importIndex: each identifier -> the identifiers it includes (from the merged graph edges).
      importIndex = prelude.foldl' (
        acc: e: acc // { ${e.from} = (acc.${e.from} or [ ]) ++ [ e.to ]; }
      ) { } merged.graph.edges;
      # ── gen-scope's ENTRY RECORD ──
      # `buildRoots` returns `{ nodes, nodeOrder }` — the node set together with its DECLARED
      # vertex order — and every evaluator entry takes that whole record rather than a bare node
      # map. The two are near-indistinguishable to a caller and catastrophically different to an
      # enumerating read: handed a bare map, `allNodes` and friends answer with the record's own
      # key names and only a lookup of a known id is loud. Making the record the input TYPE is what
      # makes that call unwritable, so this library passes the record through rather than unwrapping
      # it. (`buildNodes` is a tombstone that says the same thing.)
      scopeRoots = scope.buildRoots {
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
        scope = scopeRoots;
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
      # per-requirer resolution result (keyed by the requirer's identifier) — surfaced in the return
      # so it is observable/assertable (decision 4). Only nodes WITH includes are queried.
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

      # ── step 5: the manifest ──────────────────────────────────────────────────────────────────────
      # Every row carries IDENTIFIERS AND KINDS, and never an identity. ADR-0016 ruling 5 rules the
      # derived content-address INTERNAL ADDRESSING ONLY — consistent within an evaluation, with
      # nothing durable depending on it across them — and this record is designed for a consumer to
      # serialize to a `gen-link.lock`. A serialized lock carrying identities is durable
      # cross-evaluation dependence on internal addressing, which is precisely and only what the
      # ruling forbids. What the rows carry instead is the identity function's own INPUTS, from which
      # the identity rebuilds — and the endpoint kinds are what keep that rebuild total once a
      # federation mixes kinds, because the kind is the identity's tag prefix and no other field
      # carries it once the identity stops being serialized.
      #
      # Each endpoint's kind is read from the MINTING RUN's own node record — the same value that
      # keyed that node's identity — rather than re-derived from anything here. A second derivation
      # of one fact is how the two answers start disagreeing.
      kindOf = identifier: minted.nodes.${identifier}.kind;
      manifestRow =
        kind: via: e:
        manifest.entry {
          inherit kind via;
          inherit (e) from to;
          fromKind = kindOf e.from;
          toKind = kindOf e.to;
        };

      # The hole rows are a rendering of the minting run's OWN edge rows rather than a second
      # derivation from the same wire: one row per relatum, carrying the label that keyed the
      # identity.
      manifestEntries = manifest.order (
        (map (manifestRow "includes" null) crossOriginEdges)
        ++ (map (e: manifestRow "hole" e.label e) minted.edges)
      );
    in
    {
      graph = merged.graph;
      # Both guards RUN before the manifest is observed: the completeness guard first, because an
      # unwired hole is an authoring omission whose message names the repair, then the mint, whose
      # refusal names an ill-founded relation. Forcing them here is lazy-safe and is what makes them
      # properties of the CALL rather than of a consumer's reading pattern.
      manifest = builtins.deepSeq unwiredHoleGuard (builtins.seq minted manifestEntries);
      # Each node under its identifier, carrying the identity as a FIELD rather than as its name.
      nodes = prelude.mapAttrs (
        identifier: en: en // { inherit (minted.nodes.${identifier}) identity; }
      ) merged.idToNode;
      # What `wire` bound, with the identity the fillings folded into.
      bound = map (
        w:
        {
          inherit (w)
            identifier
            relata
            origin
            node
            ;
        }
        // {
          inherit (minted.nodes.${w.identifier}) identity;
        }
      ) wired;
      inherit resolved;
    };
in
{
  inherit link;
}
