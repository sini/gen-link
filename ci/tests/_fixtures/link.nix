# THE `link` FIXTURES — the federations the seam's cells run over, and the refusal TEXTS themselves.
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
    cachereq = {
      category = "facet";
      contract = "capability";
      option = facetOpt;
    };
  };

  regOf =
    aspects:
    mkAspectRegistry {
      inherit keySemantics;
      modules = [ { config.aspects = aspects; } ];
    };
  srcOf = origin: aspects: {
    registry = (regOf aspects).config.aspects;
    inherit keySemantics;
    inherit origin;
  };

  # A pure provider, and a requirer whose one hole it fills.
  provider = {
    apps.media.pg = {
      nixos = { };
      dbcap.provides = [
        "read"
        "write"
      ];
    };
  };
  requirer = {
    apps.app = {
      nixos = { };
      dbreq.requires = [ "read" ];
    };
  };
  # A node that satisfies its OWN requirement, so a self-filling reaches the mint rather than
  # refusing at the contract guard first — which is what makes the refusal a finding about
  # ill-foundedness and not about capabilities.
  selfSufficient = {
    apps.app = {
      nixos = { };
      dbreq = {
        requires = [ "read" ];
        provides = [ "read" ];
      };
    };
  };
  # A requirer with TWO holes, so an emitted relation carries two labels.
  twoHoled = {
    apps.app = {
      nixos = { };
      dbreq.requires = [ "read" ];
      cachereq.requires = [ "read" ];
    };
  };

  sources = [
    (srcOf [ "a" ] provider)
    (srcOf [ "b" ] requirer)
  ];

  # Every refusal is reached by forcing `.manifest`: the returned record reaches weak head normal
  # form without running a single guard, so a cell projecting anything shallower asserts nothing.
  linkManifest = args: (genLink.link ({ inherit sources; } // args)).manifest;

  wired = genLink.link {
    inherit sources;
    wire."b/apps/app".dbreq = "a/apps/media/pg";
  };
in
{
  inherit
    keySemantics
    srcOf
    provider
    sources
    linkManifest
    wired
    ;

  # A self-filling: the node is its own relatum, inside one evaluation with no stratum between them.
  selfFilling = {
    sources = [
      (srcOf [ "a" ] provider)
      (srcOf [ "b" ] selfSufficient)
    ];
    wire."b/apps/app".dbreq = "b/apps/app";
  };

  # A filling cycle across two origins: each names the other, neither can be strictly earlier.
  cycle =
    let
      node = {
        nixos = { };
        dbreq = {
          requires = [ "read" ];
          provides = [ "read" ];
        };
      };
    in
    {
      sources = [
        (srcOf [ "a" ] { na = node; })
        (srcOf [ "b" ] { nb = node; })
      ];
      wire."a/na".dbreq = "b/nb";
      wire."b/nb".dbreq = "a/na";
    };

  # The same two nodes with the cycle BROKEN — `b/nb` declares no hole, so `a/na` alone requires and
  # the wire is well-founded. A refusal cell means nothing beside a fixture that cannot link at all.
  brokenCycle = {
    sources = [
      (srcOf [ "a" ] {
        na = {
          nixos = { };
          dbreq = {
            requires = [ "read" ];
            provides = [ "read" ];
          };
        };
      })
      (srcOf [ "b" ] {
        nb = {
          nixos = { };
          dbcap.provides = [ "read" ];
        };
      })
    ];
    wire."a/na".dbreq = "b/nb";
  };

  # A THREE-DEEP chain: `q` needs `m`, `m` needs `p`, `p` needs nothing. It links only if the pass
  # derivation genuinely stages — every node emitted at pass 0 would leave `m`'s relatum unfrozen.
  chain = {
    sources = [
      (srcOf [ "a" ] {
        p = {
          nixos = { };
          dbcap.provides = [ "read" ];
        };
      })
      (srcOf [ "b" ] {
        m = {
          nixos = { };
          dbreq.requires = [ "read" ];
          dbcap.provides = [ "read" ];
        };
      })
      (srcOf [ "c" ] {
        q = {
          nixos = { };
          dbreq.requires = [ "read" ];
        };
      })
    ];
    wire."c/q".dbreq = "b/m";
    wire."b/m".dbreq = "a/p";
  };

  # One requirer, two holes, two fillers.
  twoLabels = {
    sources = [
      (srcOf [ "a" ] provider)
      (srcOf [ "b" ] twoHoled)
    ];
    wire."b/apps/app" = {
      dbreq = "a/apps/media/pg";
      cachereq = "a/apps/media/pg";
    };
  };

  # ── THE REFUSAL TEXTS ──
  # The completeness guard over the merged requirer set: a declared hole that no `wire` entry names.
  # It names the requirer by its federation reference and lists the facets left unfilled, then spells
  # the entry that would fill them — a refusal that names the repair rather than only the symptom.
  unwiredHoleRefusal =
    requirerRef: facets:
    "gen-link.link: aspect '${requirerRef}' has unwired required facet(s): ${builtins.concatStringsSep ", " facets}."
    + " Wire each via `wire.\"${requirerRef}\".<facet> = <provider-ref>`.";

  # The federation-membership guard: a `wire` reference naming something the merged graph does not
  # carry. `what` names the reference's ROLE, so one text serves the requirer and the filler.
  unknownTargetRefusal =
    what: identifier:
    "gen-link.link: ${what} names '${identifier}', which is not in the federation (check origin/path, or add its source)";

  # ★ THE ENGINE'S OWN TEXT, transcribed rather than composed here. `gen-scope`'s suite is where
  # these bytes are specified; what this repository asserts is that an ill-founded federation reaches
  # that refusal at all, and that the relatum it names is a READABLE reference rather than a digest.
  # Before the migration these cases minted a well-formed identity and said nothing.
  unresolvedRelatumRefusal =
    identifier: label: kind: pass:
    "gen-scope.mintStrata: unresolved relatum '${identifier}' (label '${label}', minting kind '${kind}', pass ${toString pass})";
}
