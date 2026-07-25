# Facet reading (design §facet; decision 2). A facet is the SOLE typed port of federation. A facet key
# F is declared in a source's `keySemantics` with `category = "facet"` and a `contract` flavor
# ("capability" | "refined"). The concrete per-node contract is read from the aspect NODE's value at F:
# a PROVIDER sets `F = { provides = [tags]; }`; a REQUIRER (hole) sets `F = { requires = [tags]; }`
# (capability). A facet only TYPES an edge — it never resolves one (that is the scope-graph query).
{ prelude }:
let
  facetKeys = ks: builtins.attrNames (prelude.filterAttrs (_: e: (e.category or null) == "facet") ks);

  contractOf = ks: f: (ks.${f}.contract or "capability");

  # A facet value carrying a `requires` list is an unfilled capability HOLE.
  isHoleValue = v: builtins.isAttrs v && (v ? requires);

  holesOf = ks: node: builtins.filter (f: (node ? ${f}) && isHoleValue node.${f}) (facetKeys ks);

  # The demand of a capability hole: its `requires` tag list.
  requiresOf = node: f: (node.${f}.requires or [ ]);

  # A node's total capability PROVIDES: the union over its facet keys of any `provides` list it sets.
  providesOf =
    ks: node:
    prelude.unique (
      prelude.concatMap (
        f: if (node ? ${f}) && builtins.isAttrs node.${f} && (node.${f} ? provides) then node.${f}.provides else [ ]
      ) (facetKeys ks)
    );
in
{
  inherit
    facetKeys
    contractOf
    isHoleValue
    holesOf
    requiresOf
    providesOf
    ;
}
