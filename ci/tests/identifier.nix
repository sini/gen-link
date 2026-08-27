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

  # ── THE COORDINATE IS THE ASPECT CHAIN, NOT THE `.key` ATTRIBUTE ──
  # `key` is a live option on an aspect node and overriding it looks like it should re-name the node.
  # It does not: the coordinate is `pathKey ((meta.aspect-chain or []) ++ [ name ])`, which is the
  # same reading a keyRef's path gets, and joining the two by a spelling nothing keeps in step is how
  # they would start disagreeing. `name` is the live field — the positive control below.
  flake.tests.identifier.test-overriding-the-key-attribute-does-not-rename-the-vertex = {
    expr =
      builtins.elem "x/helper"
        (stampTampered (n: n // { key = "totally/different"; })).graph.vertices;
    expected = true;
  };
  flake.tests.identifier.test-overriding-the-name-does-rename-the-vertex = {
    expr = builtins.elem "x/helper" (stampTampered (n: n // { name = "renamed"; })).graph.vertices;
    expected = false;
  };
}
