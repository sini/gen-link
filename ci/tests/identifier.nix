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
  genPrelude,
  ...
}:
let
  # The identifier's two constructions, which `link` reads and does not re-export.
  ref = import ../../lib/ref.nix {
    prelude = genPrelude;
    inherit aspects;
  };
  distinct = xs: builtins.length xs == builtins.length (genPrelude.unique xs);
  # `"f/x"` beside `f.x`: one segment holding the separator, and two segments.
  pair =
    (mkAspectRegistry {
      keySemantics = classKs;
      modules = [
        {
          config.aspects = {
            "f/x".nixos = { };
            f.x.nixos = { };
          };
        }
      ];
    }).config.aspects;
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

  federated = genLink.link { } [
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

  norm = genLink.normalize reg.config.aspects;
  # Stamp a normalized registry after tampering with one node's value, WITHOUT moving it in the map.
  stampTampered =
    f:
    genLink.originStamp { } [ "x" ] (
      norm
      // {
        nodesByKey = norm.nodesByKey // {
          helper = f norm.nodesByKey.helper;
        };
      }
    );
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

  # ── THE IDENTIFIER IS INJECTIVE (den-hoag-gywcg) ──
  # Every string that names a node is a rendering, and a rendering that names must be injective
  # (ADR-0034, g1qy0). The key renders through gen-aspects' one escaping rendering, and the origin is
  # ONE segment of the identifier, so the origin/key boundary is recoverable. Before, each pair below
  # rendered alike.
  flake.tests.identifier.test-the-identifier-is-injective = {
    expr = {
      separatorKey = distinct [
        (ref.nodeIdentifier [ "o" ] pair."f/x")
        (ref.nodeIdentifier [ "o" ] pair.f.x)
      ];
      originBoundary = distinct [
        (ref.refIdentifier {
          origin = [ "a" ];
          key = aspects.pathKey [
            "b"
            "c"
          ];
        })
        (ref.refIdentifier {
          origin = [
            "a"
            "b"
          ];
          key = aspects.pathKey [ "c" ];
        })
      ];
      separatorOrigin = distinct [
        (genLink.originLabel [ "a/b" ])
        (genLink.originLabel [
          "a"
          "b"
        ])
      ];
      # CONTROLS: two plainly distinct origins, and the documented self alias.
      ctl = distinct [
        (genLink.originLabel [ "a" ])
        (genLink.originLabel [ "b" ])
      ];
      selfIsEmpty = genLink.renderOrigin [ ] == genLink.renderOrigin [ "self" ];
    };
    expected = {
      separatorKey = true;
      originBoundary = true;
      separatorOrigin = true;
      ctl = true;
      selfIsEmpty = true;
    };
  };
}
