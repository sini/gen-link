# Normalize a source aspect registry into a source-relative, ORIGIN-FREE graph (design §statement 2):
# nodes keyed by their `.key`, `includes` extracted UNIFORMLY as id-edges. A registry is a labeled
# graph, not a tree of values (Neron 2015): nodes + `includes` edges. The two `includes` forms are
# authoring ergonomics only — by-value (target read from the value's `.key`) and by-key (keyRef, a
# dangling `@ref:` edge the union resolves) — and at the graph level the distinction DISAPPEARS. No
# content re-evaluation happens here. (`aspects` is NOT a dependency — parsing rides `ref`.)
{
  prelude,
  ref,
}:
let
  refPrefix = "@ref:";
  hasRefPrefix = prelude.hasPrefix refPrefix;

  # An aspect NODE is a plain submodule value carrying the aspect signature. This distinguishes real
  # nodes from class content (deferredModule), facet VALUES (now declared options — decision 2 — never
  # nested aspects), and meta — none carry all four options. Wrapped-fn/guard aspects are bare records
  # lacking `id_hash`/`includes`, so they are DROPPED (out of base scope, decision 5). The `? key` /
  # `isAttrs` probe forces each candidate child to WHNF (the attrset head) ONLY — a class deferredModule
  # body is never forced, so "no content re-evaluation" holds in the deep sense (bounded head-touch).
  isNode = v: builtins.isAttrs v && v ? key && v ? name && v ? includes && v ? id_hash;

  # Enumerate every aspect node in the tree; a node's nested-aspect children ride its freeform attrs.
  # `includes` is removed before the child scan so by-value references (which name OTHER nodes already
  # enumerated from the tree) are not double-counted or cycled through.
  enumerate =
    node:
    [ node ]
    ++ prelude.concatMap enumerate (
      builtins.filter isNode (builtins.attrValues (builtins.removeAttrs node [ "includes" ]))
    );

  allNodes =
    registry: prelude.concatMap enumerate (builtins.filter isNode (builtins.attrValues registry));

  # Extract one node's includes-edges. by-value: the target's `.key`. by-key (keyRef): an `@ref:` token
  # carrying the parsed ref. A raw-fn / guard include with no readable key contributes no federated
  # edge in the base mechanism.
  edgesOf =
    node:
    prelude.concatMap (
      inc:
      if builtins.isAttrs inc && (inc.__keyRef or false) then
        let
          r = ref.parseRef inc;
          token = refPrefix + ref.renderOrigin r.origin + "/" + r.key;
        in
        [
          {
            from = node.key;
            to = token;
            parsedRef = r;
          }
        ]
      else if builtins.isAttrs inc && inc ? key then
        [
          {
            from = node.key;
            to = inc.key;
            parsedRef = null;
          }
        ]
      else
        [ ]
    ) node.includes;

  normalize =
    registry:
    let
      nodes = allNodes registry;
      nodesByKey = prelude.listToAttrs (
        map (n: {
          name = n.key;
          value = n;
        }) nodes
      );
      allEdges = prelude.concatMap edgesOf nodes;
      refByToken = prelude.listToAttrs (
        map (e: {
          name = e.to;
          value = e.parsedRef;
        }) (builtins.filter (e: e.parsedRef != null) allEdges)
      );
      edges = map (e: { inherit (e) from to; }) allEdges;
    in
    {
      inherit nodesByKey edges refByToken;
    };
in
{
  inherit
    normalize
    isNode
    hasRefPrefix
    refPrefix
    ;
}
