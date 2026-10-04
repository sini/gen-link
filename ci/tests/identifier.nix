# THE IDENTIFIER — the name a federation node carries as a vertex, and the join that makes a
# cross-origin reference reach the node it names.
#
# ★ WHAT THESE CELLS REPLACED. This file used to assert four properties of `nodeId` and
# `keyRefTargetId`, both retired: the addressing is no longer a content-address, so there is nothing
# left for a hash constructor to construct. Two of those four were not about the hash at all — they
# were about the COORDINATE, and they survive here in the form the new addressing gives them.
{
  genLink,
  aspects,
  mkAspectRegistry,
  ...
}:
let
  # ★ ONE vocabulary, read by the registries AND by the source entries. `link` refuses a source that
  # declares no `keySemantics` — a class-only federation says so with this attrset rather than by
  # omitting the field, because the omission's other reading is "the vocabulary was not passed", and
  # that one silently blinds the hole guard to the source's own nodes.
  classKs = {
    nixos.category = "class";
  };
  reg = mkAspectRegistry {
    keySemantics = classKs;
    modules = [
      (
        { ... }:
        {
          config.aspects = {
            helper.nixos = { };
            main = {
              nixos = { };
              includes = [ (aspects.keyRef "y/apps/media/pg") ];
            };
          };
        }
      )
    ];
  };
  target = mkAspectRegistry {
    keySemantics = classKs;
    modules = [ { config.aspects.apps.media.pg.nixos = { }; } ];
  };

  federated = genLink.link {
    sources = [
      {
        registry = reg.config.aspects;
        keySemantics = classKs;
        origin = [ "x" ];
      }
      {
        registry = target.config.aspects;
        keySemantics = classKs;
        origin = [ "y" ];
      }
    ];
  };

  norm = genLink.normalize reg.config.aspects;
  # Stamp a normalized registry after tampering with one node's value, WITHOUT moving it in the map.
  stampTampered =
    f:
    genLink.originStamp {
      normalized = norm // {
        nodesByKey = norm.nodesByKey // {
          helper = f norm.nodesByKey.helper;
        };
      };
      origin = [ "x" ];
    };
in
{
  # ── THE JOIN ──
  # A by-key include is relabelled from the keyRef's OWN origin, and a node is named from the origin
  # it was stamped with. The two constructions have to produce the same string or a cross-origin
  # reference lands on a vertex the node map does not carry — which used to mean "declared holes read
  # as unwired" and was reachable through a second identity authority. As STRINGS the join is a
  # property of the two constructions rather than of a lock collapsing two formulas onto one.
  flake.tests.identifier.test-a-keyref-include-lands-on-the-node-map-key = {
    expr = builtins.any (
      e: e.kind == "includes" && e.from == "x/main" && e.to == "y/apps/media/pg"
    ) federated.manifest;
    expected = true;
  };
  flake.tests.identifier.test-the-keyref-target-is-a-node-the-federation-carries = {
    expr = federated.nodes ? "y/apps/media/pg";
    expected = true;
  };

  # ── THE COORDINATE IS THE DECLARED PATH, NOT A FIELD A CALLER WRITES ──
  # The identifier is built from `aspects.key`, which for a typed node is `pathKey meta.loc`: the
  # declared path the aspect type stamps from the merge position (gen-aspects identity design §1).
  # `key` and `name` are live options on an aspect node and overriding either looks like it should
  # re-name the node. Neither does: `.key` is the default of `aspects.key` and never read by it, and
  # `name` is a rendering of the declared path, never an input. The positive control moves the
  # declared path itself, so a dead harness cannot satisfy the two cells that expect no move.
  flake.tests.identifier.test-overriding-the-key-attribute-does-not-rename-the-vertex = {
    expr =
      builtins.elem "x/helper"
        (stampTampered (n: n // { key = "totally/different"; })).graph.vertices;
    expected = true;
  };
  flake.tests.identifier.test-overriding-the-name-does-not-rename-the-vertex = {
    expr = builtins.elem "x/helper" (stampTampered (n: n // { name = "renamed"; })).graph.vertices;
    expected = true;
  };
  # POSITIVE CONTROL: the declared path moved (with the chain that renders it, which must agree or
  # the key refuses) moves the vertex.
  flake.tests.identifier.test-moving-the-declared-path-does-rename-the-vertex = {
    expr =
      builtins.elem "x/helper"
        (stampTampered (
          n:
          n
          // {
            meta = n.meta // {
              loc = [
                "elsewhere"
                "renamed"
              ];
              aspect-chain = [ "elsewhere" ];
            };
          }
        )).graph.vertices;
    expected = false;
  };
}
