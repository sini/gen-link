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
  appNodeId = genLink.nodeId [ "b" ] regB.config.aspects.apps.app;
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
  # gen-resolve is load-bearing: B/app's cross-origin include resolves (via reference) to A/pg's
  # provided capability tags. A stubbed `reference` -> null here.
  flake.tests.link.test-resolution-through-gen-resolve = {
    expr = result.resolved.${appNodeId};
    expected = [
      "read"
      "write"
    ];
  };
  flake.tests.link.test-absent-wire-target-throws = {
    expr = badWire.success;
    expected = false;
  };
}
