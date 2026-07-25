# Origin-rewrite (design §statement 2 / Federation step 1): a UNIFORM relabel over the normalized
# graph. `overlay` alone is shared-namespace (bare-id vertices collide); gen-link makes the union
# disjoint by first stamping every node with a federation origin — a coproduct injection (Mokhov 2017;
# category-theoretic coproduct). This is strictly MORE than gen-scope `gmap` on a value graph, because
# the id-references were already normalized into graph edges — so ONE relabel touches every include,
# however it was authored. No content re-evaluation. Per-node `alias` renames a node's key here.
{
  prelude,
  scope,
  identity,
  normalize,
}:
let
  # Build the source-relative gen-scope graph: vertices = local keys, edges = local key -> key|@ref.
  toGraph =
    nodesByKey: edges:
    scope.overlay (scope.vertices (builtins.attrNames nodesByKey)) (scope.edges edges);

  # The relabel: local key -> federation id (aspectId under the assigned origin); @ref token -> the
  # cross-origin target id (read from the keyRef's OWN origin, NEVER the assigned one — decision 6).
  # gmap applies this to every vertex AND every edge endpoint uniformly, so by-value and by-key edges
  # are relabeled identically.
  relabelFn =
    {
      origin,
      nodesByKey,
      refByToken,
    }:
    k: if refByToken ? ${k} then identity.keyRefTargetId refByToken.${k} else identity.nodeId origin nodesByKey.${k};

  # Split an alias target ("apps/media/postgres") into { chain; last } so `identity.key` recomputes.
  splitSlash = s: builtins.filter (x: builtins.isString x && x != "") (builtins.split "/" s);

  # Apply an alias to a node: override `name` + `meta.aspect-chain` so `aspects.aspectId` (which reads
  # `identity.key` = pathKey ((meta.aspect-chain or []) ++ [name]), NOT `.key`) recomputes to the new
  # path. Overriding `.key` alone is DEAD — aspectId never reads it. This makes the aliased id genuinely
  # differ (Fix 3). `alias` is passed EXPLICITLY (it is `originStamp`'s formal, not in this outer `let`).
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
        };
      };

  originStamp =
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
          name = identity.nodeId origin n;
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
in
{
  inherit originStamp toGraph relabelFn;
}
