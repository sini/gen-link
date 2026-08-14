# THE `link` FIXTURES — the federation the refusal cells run over, and the refusal TEXTS themselves.
#
# NOT A SUITE. It sits under `_fixtures/` because the tree importer ignores any path containing
# `/_`, so this file is reached only by what imports it and never as a flake module.
#
# ★ WHY THE TEXTS LIVE HERE RATHER THAN IN THE CELLS THAT ASSERT THEM. A refusal is required to name
# specific coordinates — which aspect, which facets, which reference — and nothing outside this
# repository fixes those bytes, so the literals below ARE the specification of them. A specification
# with two copies has two answers the moment one of them is edited, and the cells that read these
# are split across two flake outputs by the SHAPE of their assertion rather than by their subject.
{
  genLink,
  genMerge,
  mkAspectRegistry,
}:
let
  facetOpt = genMerge.mkOption {
    type = genMerge.types.raw;
    default = null;
  };

  keySemantics = {
    nixos.category = "class";
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

  # A provider at origin `a` and a requirer at origin `b`: the smallest federation carrying a hole.
  regA = mkAspectRegistry {
    inherit keySemantics;
    modules = [
      {
        config.aspects.apps.media.pg = {
          nixos = { };
          dbcap.provides = [
            "read"
            "write"
          ];
        };
      }
    ];
  };
  regB = mkAspectRegistry {
    inherit keySemantics;
    modules = [
      {
        config.aspects.apps.app = {
          nixos = { };
          dbreq.requires = [ "read" ];
        };
      }
    ];
  };

  sources = [
    {
      registry = regA.config.aspects;
      inherit keySemantics;
      origin = [ "a" ];
    }
    {
      registry = regB.config.aspects;
      inherit keySemantics;
      origin = [ "b" ];
    }
  ];

  # Every refusal is reached by forcing `.manifest`: the returned record reaches weak head normal
  # form without running a single guard, so a cell projecting anything shallower asserts nothing.
  linkManifest = args: (genLink.link ({ inherit sources; } // args)).manifest;
in
{
  inherit
    keySemantics
    regA
    regB
    sources
    linkManifest
    ;

  # ── THE REFUSAL TEXTS ──
  # The completeness guard over the merged requirer set: a declared hole that no `wire` entry names.
  # It names the requirer by its federation reference and lists the facets left unfilled, then spells
  # the entry that would fill them — a refusal that names the repair rather than only the symptom.
  unwiredHoleRefusal =
    requirerRef: facets:
    "gen-link.link: aspect '${requirerRef}' has unwired required facet(s): ${builtins.concatStringsSep ", " facets}."
    + " Wire each via `wire.\"${requirerRef}\".<facet> = <provider-ref>`.";

  # The federation-membership guard: a `wire` reference resolving to something the merged graph does
  # not carry. `what` names the reference's ROLE, so one text serves the requirer and the filler.
  unknownTargetRefusal =
    what: id:
    "gen-link.link: ${what} resolves to id '${id}' which is not in the federation (check origin/path, or add its source)";
}
