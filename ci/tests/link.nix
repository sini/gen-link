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
  # ★ THE REQUIRER HERE HAS TO BE A REAL ONE. This used to wire `a/apps/media/pg` — a pure PROVIDER,
  # which declares no `dbreq` hole — and the wire site now refuses that before it ever resolves the
  # filler, so the cell below would have stayed green while measuring the undeclared-hole refusal
  # under a name that says absent target. `b/apps/app` declares the hole, so the only defect left in
  # this federation is the filler naming a coordinate nothing carries. (Measured: the provider form
  # answers `wire entry 'a/apps/media/pg.dbreq' names no declared hole … (declared: none)`.)
  badWire = builtins.tryEval (
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
      wire."b/apps/app".dbreq = "a/nonexistent";
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

  # ── THE GUARD'S REACH, AND THE TWO ABSENCES THAT USED TO DISABLE IT ──
  fixtures = import ./_fixtures/link.nix {
    inherit
      genLink
      genMerge
      aspects
      mkAspectRegistry
      ;
  };
  # Every field of the result, forced the way the trap was measured. `deepSeq` rather than `seq`
  # because a shallow force reaches nothing under a lazily-built field, and the point of the cell is
  # what a CONSUMER's reading reaches.
  fields = [
    "graph"
    "bound"
    "resolved"
    "nodes"
  ];
  fieldEvaluates =
    res: builtins.map (f: (builtins.tryEval (builtins.deepSeq res.${f} true)).success) fields;
  links = args: (builtins.tryEval (builtins.deepSeq (genLink.link args).manifest true)).success;
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

  # ── THE COMPLETENESS GUARD REACHES EVERY FIELD ──
  # The cell above forces `.manifest`, which is where the guard used to be forced — and it was the
  # ONLY field that reached it: on the same open federation `graph`, `bound`, `resolved` and `nodes`
  # each evaluated clean, so a consumer reading the merged graph or enumerating the node map got a
  # silent pass on a hole nothing filled. The expected list is written out per field so a fix that
  # covers three of the four fails here rather than passing on an `any`.
  flake.tests.link.test-the-completeness-guard-fires-on-every-field = {
    expr = fieldEvaluates fixtures.unwired;
    expected = [
      false
      false
      false
      false
    ];
  };
  # ★ THE CONTROL, SAME INSTRUMENT AND SAME RUN. The same four fields of the same federation with
  # the hole WIRED still evaluate, so what the refusals above report is the open hole and not a
  # `deepSeq` that cannot survive these fields at all.
  flake.tests.link.test-control-every-field-evaluates-on-a-closed-federation = {
    expr = fieldEvaluates fixtures.wired;
    expected = [
      true
      true
      true
      true
    ];
  };

  # ── A SOURCE'S MISSING VOCABULARY IS A REFUSAL, NOT AN EMPTY ONE ──
  # `keySemantics` omitted from the requirer's source entry used to disable the guard for that
  # source's OWN nodes — `holesOf { }` sees no hole on a node that declares one — so this exact
  # federation linked green with `b/apps/app#dbreq` open. The message cell next door
  # (`tests-error.nix`) is what tells this refusal apart from the unwired-hole one; the control on
  # the same predicate is `facets.test-holes-of-requirer`, which reads `[ "dbreq" ]` off the same
  # node WITH the vocabulary in hand.
  flake.tests.link.test-a-source-without-keysemantics-refuses = {
    expr = links { sources = fixtures.sourcesMissingKs; };
    expected = false;
  };

  # ── A FILLING FILLS A DECLARED HOLE ──
  # `notAFacet` names nothing any source declares. It used to be accepted (`contractOf` answers
  # "capability" for any key and `requiresOf` answers `[ ]` for an undeclared one, so the contract
  # check passed vacuously), become a relatum, and fork the requirer's identity on a name no
  # signature carries.
  flake.tests.link.test-a-filling-naming-no-declared-hole-refuses = {
    expr = links fixtures.undeclaredFilling;
    expected = false;
  };
  # ★ THE CONTROL, AND IT IS THE SAME WIRE MINUS ONE KEY. The declared filling still binds and still
  # arrives as the relatum that keys the identity — so the refusal above is the undeclared name and
  # not the wire site rejecting fillings generally. (`minting.test-every-merged-node-carries-an-
  # identity` is the standing control that the identity itself still mints from these relata.)
  flake.tests.link.test-control-a-declared-hole-filling-still-binds = {
    expr = (builtins.head fixtures.wired.bound).relata;
    expected = {
      dbreq = "a/apps/media/pg";
    };
  };
}
