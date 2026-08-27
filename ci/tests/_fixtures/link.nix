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
  aspects,
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

  # `tree`, not `aspects` — the module formal `aspects` is the gen-aspects library, and shadowing it
  # with an aspect tree is one edit away from a cell reading the wrong one.
  regOf =
    tree:
    mkAspectRegistry {
      inherit keySemantics;
      modules = [ { config.aspects = tree; } ];
    };
  srcOf = origin: tree: {
    registry = (regOf tree).config.aspects;
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
  # The requirer also INCLUDES the provider by key, so the federation carries both manifest row
  # sorts — an `includes` edge and a `hole` filling — and a cell about rows sees both.
  requirer = {
    apps.app = {
      nixos = { };
      dbreq.requires = [ "read" ];
      includes = [ (aspects.keyRef "a/apps/media/pg") ];
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

  # The SAME federation with nothing wired: `b/apps/app` declares a `dbreq` hole and no `wire` entry
  # names it. Held as a value rather than a `linkManifest` call because the cells over it project
  # each field of the result in turn.
  unwired = genLink.link { inherit sources; };
in
{
  inherit
    keySemantics
    srcOf
    provider
    sources
    linkManifest
    wired
    unwired
    ;

  # The requirer's source entry with its `keySemantics` REMOVED — `removeAttrs` over the same
  # constructor, so the omission is the only difference from `sources` above and a cell over it is
  # measuring the omission rather than a second hand-written fixture.
  sourcesMissingKs = [
    (srcOf [ "a" ] provider)
    (removeAttrs (srcOf [ "b" ] requirer) [ "keySemantics" ])
  ];

  # A filling naming a facet no source declares, BESIDE the real one — the shape the wire site used
  # to accept: `notAFacet` type-checked vacuously (nothing declares it, so nothing is required of
  # it), became a relatum and forked `b/apps/app`'s identity. Holding the real filling alongside is
  # what makes the control below the same wire minus one key.
  undeclaredFilling = {
    inherit sources;
    wire."b/apps/app" = {
      dbreq = "a/apps/media/pg";
      notAFacet = "a/apps/media/pg";
    };
  };

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

  # The vocabulary guard: a source that never passed its `keySemantics`. The refusal names the
  # ORIGIN, because that is the only coordinate a source entry has, and it spells the explicit empty
  # declaration — the omission's two readings are told apart by the author, not by a default.
  missingKeySemanticsRefusal =
    originLabel:
    "gen-link.link: source at origin '${originLabel}' declares no `keySemantics`, so its own facets — and every hole they declare — would be invisible."
    + " Declare the source's facet vocabulary, or `keySemantics = { }` if it genuinely has none.";

  # The wire-site guard: a filling naming a facet that is no declared hole on the requirer. The text
  # lists what IS declared, so a misspelling shows itself beside the name it missed, and it names
  # both repairs — the filling may be the mistake or the missing declaration may be.
  undeclaredHoleRefusal =
    requirerRef: identifier: facet: holes:
    "gen-link.link: wire entry '${requirerRef}.${facet}' names no declared hole on '${identifier}' (declared: ${
      if holes == [ ] then "none" else builtins.concatStringsSep ", " holes
    })."
    + " Declare the hole (`${facet} = { requires = [ … ]; }`, with a `category = \"facet\"` keySemantics entry) or drop the filling.";

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
