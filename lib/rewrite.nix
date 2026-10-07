# Origin-rewrite (design §statement 2 / Federation step 1): a UNIFORM relabel over the normalized
# graph. `overlay` alone is shared-namespace (bare-id vertices collide); gen-link makes the union
# disjoint by first stamping every node with a federation origin — a coproduct injection (Mokhov 2017;
# category-theoretic coproduct). This is strictly MORE than gen-scope `gmap` on a value graph, because
# the id-references were already normalized into graph edges — so ONE relabel touches every include,
# however it was authored. No content re-evaluation. Per-node `alias` renames a node's key here.
{
  prelude,
  scope,
  ref,
  normalize,
}:
let
  # Build the source-relative gen-scope graph: vertices = local keys, edges = local key -> key|@ref.
  toGraph =
    nodesByKey: edges:
    scope.overlay (scope.vertices (builtins.attrNames nodesByKey)) (scope.edges edges);

  # The relabel: local key -> the node's federation IDENTIFIER (origin-qualified reference under the
  # assigned origin); @ref token -> the cross-origin target's identifier (read from the keyRef's OWN
  # origin, NEVER the assigned one — decision 6). gmap applies this to every vertex AND every edge
  # endpoint uniformly, so by-value and by-key edges are relabeled identically.
  relabelFn =
    {
      origin,
      nodesByKey,
      refByToken,
    }:
    k:
    if refByToken ? ${k} then
      ref.refIdentifier refByToken.${k}
    else if nodesByKey ? ${k} then
      ref.nodeIdentifier origin nodesByKey.${k}
    else
      throw "gen-link.rewrite: an includes entry in origin '${ref.renderOrigin origin}' names '${k}', which is not a key in this source's registry (check the includes entry naming it, or that a node with this key exists)";

  # Split an alias target ("apps/media/postgres") into { chain; last } so `identity.key` recomputes.
  splitSlash = ref.parsePath;

  # Apply an alias to a node: relabel its declared path, `meta.loc`, so `aspects.key` (= pathKey
  # meta.loc for a typed node, NOT `.key` and NOT `name`) recomputes to the new path. `name` and
  # `meta.aspect-chain` are its renderings and are rewritten to agree with it: a chain that contradicts
  # the declared path refuses by name. Overriding `.key` alone is DEAD — the identifier never reads it.
  # This makes the aliased node genuinely a different vertex (Fix 3). `alias` is passed EXPLICITLY (it
  # is `originStamp`'s formal, not this outer `let`'s).
  aliasNode =
    alias: k: n:
    if !(alias ? ${k}) then
      n
    else
      let
        segs = splitSlash alias.${k};
      in
      n
      // {
        key = alias.${k};
        name = prelude.last segs;
        meta = (n.meta or { }) // {
          aspect-chain = prelude.init segs;
          loc = segs;
        };
      };

  # The stamp itself. `link` calls it with the record it builds; the published door is below.
  stamp =
    {
      normalized,
      origin,
      alias ? { },
    }:
    let
      aliasKey = k: alias.${k} or k;
      nodesByKey = prelude.listToAttrs (
        prelude.mapAttrsToList (k: n: {
          name = aliasKey k;
          value = aliasNode alias k n;
        }) normalized.nodesByKey
      );
      edges = map (e: {
        from = aliasKey e.from;
        to = if normalize.hasRefPrefix e.to then e.to else aliasKey e.to;
      }) normalized.edges;
      relabel = relabelFn {
        inherit origin nodesByKey;
        inherit (normalized) refByToken;
      };
      graph = scope.gmap relabel (toGraph nodesByKey edges);
      idToNode = prelude.listToAttrs (
        prelude.mapAttrsToList (_k: n: {
          name = ref.nodeIdentifier origin n;
          value = {
            inherit origin;
            node = n;
          };
        }) nodesByKey
      );
    in
    {
      inherit graph idToNode;
    };

  # `originStamp { alias ?; } origin normalized` (den-hoag-7gp66 P2, rules 2 and 4). The one option,
  # `alias`, is a closed options set first, a `prelude.door` refused by name and catchably at
  # `originStamp opts`'s own WHNF. The origin is configuration and the normalized graph the subject the
  # stamp relabels, so `originStamp { } origin` is an injection mapped over subgraphs. The result is a
  # record, so the origin check is forced ahead of it: a bad origin is refused naming this door rather
  # than `renderOrigin`, at the call and not at a later field read.
  originStamp =
    prelude.door
      {
        name = "gen-link.originStamp";
        optional = [ "alias" ];
      }
      (
        o: origin: normalized:
        builtins.seq (ref.checkOrigin "originStamp" origin) (stamp (o // { inherit normalized origin; }))
      );
in
{
  inherit
    stamp
    originStamp
    toGraph
    relabelFn
    ;
}
