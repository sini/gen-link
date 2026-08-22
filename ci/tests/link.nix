{
  genLink,
  genMerge,
  aspects,
  mkAspectRegistry,
  ...
}:
let
  facetOpt = genMerge.mkOption {
    type = genMerge.types.raw;
    default = null;
  };
  ks = {
    nixos = {
      category = "class";
    };
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
  regA = mkAspectRegistry {
    keySemantics = ks;
    modules = [
      {
        config.aspects.apps.media.pg = {
          nixos = { };
          dbcap = {
            provides = [
              "read"
              "write"
            ];
          };
        };
      }
    ];
  };
  regB = mkAspectRegistry {
    keySemantics = ks;
    modules = [
      {
        config.aspects.apps = {
          media.pg.nixos = { }; # SAME path as A
          app = {
            nixos = { };
            dbreq = {
              requires = [ "read" ];
            };
            includes = [ (aspects.keyRef "a/apps/media/pg") ]; # cross-origin include
          };
        };
      }
    ];
  };
  result = genLink.link {
    sources = [
      {
        registry = regA.config.aspects;
        keySemantics = ks;
        origin = [ "a" ];
      }
      {
        registry = regB.config.aspects;
        keySemantics = ks;
        origin = [ "b" ];
      }
    ];
    wire."b/apps/app".dbreq = "a/apps/media/pg";
  };
  holeEntries = builtins.filter (e: e.kind == "hole") result.manifest;
  includeEntries = builtins.filter (e: e.kind == "includes") result.manifest;
  appIdentifier = "b/apps/app";
  badWire = builtins.tryEval (
    (genLink.link {
      sources = [
        {
          registry = regA.config.aspects;
          keySemantics = ks;
          origin = [ "a" ];
        }
      ];
      wire."a/apps/media/pg".dbreq = "a/nonexistent";
    }).manifest
  );
  # A MERGED requirer (b/apps/app carries the `dbreq` requires-hole) with NO `wire` entry at all.
  # Both sources are present so the cross-origin `includes` resolves — the ONLY defect is the
  # unwired hole. Decision 7 demands a loud, named error, not a silent unbound success.
  unwiredRequirer = builtins.tryEval (
    (genLink.link {
      sources = [
        {
          registry = regA.config.aspects;
          keySemantics = ks;
          origin = [ "a" ];
        }
        {
          registry = regB.config.aspects;
          keySemantics = ks;
          origin = [ "b" ];
        }
      ];
      # deliberately no `wire`: b/apps/app#dbreq is left unfilled.
    }).manifest
  );

  # ── THE TWO-PROVIDING-INCLUDE FEDERATION ──
  #
  # ★★★ THE SHAPE THIS SUITE COULD NOT SEE. `includes` is a plural list and always has been, but
  # every declaration reaching `link` here named exactly ONE key — so the resolution of a
  # multi-include node was read by no cell, and a change in how the authority disposes of a
  # non-singleton candidate set could pass this whole suite while the live behaviour moved under
  # it.
  #
  # `a` provides twice: `pg` carries the read/write capability, `redis` carries the cache one.
  # `b/apps/app` includes BOTH by key, so `resolvedProvides` is asked for one datum from two
  # DISTINCT declaring nodes. That is an ambiguity (Neron 2015 §2.2, Duplicate Declarations) and
  # the engine refuses by name; it used to answer `[ "read" "write" ]` and drop `[ "cache" ]` in
  # silence. `referenceResolution` is TOTAL DELEGATION, so the refusal arrives unchanged in kind
  # rather than being authored anywhere in this repository — which is what makes this the
  # end-to-end witness that the delegation carries a refusal across a real federation.
  twoProvidingRegA = mkAspectRegistry {
    keySemantics = ks;
    modules = [
      {
        config.aspects.apps.media = {
          pg = {
            nixos = { };
            dbcap.provides = [
              "read"
              "write"
            ];
          };
          redis = {
            nixos = { };
            dbcap.provides = [ "cache" ];
          };
        };
      }
    ];
  };
  # The requirer is parameterised by the keys it includes and by nothing else — the class, the
  # hole and the wire below are held identical — so the two readings differ in the second include
  # and not in a second hand-written fixture.
  requirerIncluding =
    keys:
    mkAspectRegistry {
      keySemantics = ks;
      modules = [
        {
          config.aspects.apps.app = {
            nixos = { };
            dbreq.requires = [ "read" ];
            includes = map aspects.keyRef keys;
          };
        }
      ];
    };
  linkIncluding =
    keys:
    builtins.tryEval (
      builtins.deepSeq
        (genLink.link {
          sources = [
            {
              registry = twoProvidingRegA.config.aspects;
              keySemantics = ks;
              origin = [ "a" ];
            }
            {
              registry = (requirerIncluding keys).config.aspects;
              keySemantics = ks;
              origin = [ "b" ];
            }
          ];
          wire."b/apps/app".dbreq = "a/apps/media/pg";
        }).resolved.${appIdentifier}
        true
    );
  twoProvidingIncludes = linkIncluding [
    "a/apps/media/pg"
    "a/apps/media/redis"
  ];
  oneProvidingInclude = linkIncluding [ "a/apps/media/pg" ];
in
{
  flake.tests.link.test-returns-graph-and-manifest = {
    expr =
      (result ? graph)
      && (result ? manifest)
      && (result ? nodes)
      && (result ? bound)
      && (result ? resolved);
    expected = true;
  };
  flake.tests.link.test-manifest-records-hole = {
    expr = builtins.length holeEntries;
    expected = 1;
  };
  flake.tests.link.test-hole-endpoints = {
    expr = (builtins.head holeEntries).via;
    expected = "dbreq";
  };
  flake.tests.link.test-manifest-records-cross-origin-include = {
    expr = builtins.length includeEntries >= 1;
    expected = true;
  };
  # the reference-resolution construct is load-bearing: B/app's cross-origin include resolves to A/pg's
  # provided capability tags. A stubbed `reference` -> null here.
  flake.tests.link.test-resolution-through-reference-resolution = {
    expr = result.resolved.${appIdentifier};
    expected = [
      "read"
      "write"
    ];
  };
  flake.tests.link.test-absent-wire-target-throws = {
    expr = badWire.success;
    expected = false;
  };
  # A node including TWO providing aspects asks the engine for one datum from two distinct
  # declaring nodes, and the read refuses rather than answering one of them and dropping the other.
  flake.tests.link.test-two-providing-includes-refuse = {
    expr = twoProvidingIncludes.success;
    expected = false;
  };
  # ★ THE CONTROL, AND IT IS THE SAME FEDERATION. `a` still carries both providers; only the
  # requirer's `includes` shrinks to one key. So the refusal above is the SECOND INCLUDE and not
  # the presence of a second provider somewhere in the federation, and not a fixture that failed to
  # link at all. The two pre-existing single-include resolution cells — this suite's
  # `test-resolution-through-reference-resolution` and `conductor-oracle`'s
  # `test-reference-resolution-resolves-provider` — remain the controls on the shipped shape.
  flake.tests.link.test-control-one-providing-include-still-resolves = {
    expr = oneProvidingInclude.success;
    expected = true;
  };
  # decision 7: a merged requirer whose required facet is never wired is a LOUD, named error.
  flake.tests.link.test-unwired-required-facet-throws = {
    expr = unwiredRequirer.success;
    expected = false;
  };
}
