{
  genLink,
  genMerge,
  mkAspectRegistry,
  ...
}:
let
  # A facet option MUST be declared (decision 2 / Fix 2) — a raw slot carrying the contract shape.
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
  reg = mkAspectRegistry {
    keySemantics = ks;
    modules = [
      {
        config.aspects = {
          provider.dbcap = {
            provides = [
              "read"
              "write"
            ];
          };
          requirer.dbreq = {
            requires = [ "read" ];
          };
        };
      }
    ];
  };
  provider = reg.config.aspects.provider;
  requirer = reg.config.aspects.requirer;

  # A capability union is a SET taken in first-occurrence order: the fold over a node's facet keys
  # removes repeats and keeps the order the tags were contributed in. Neither half of that contract
  # is observable through `provider` above — its one contributing key carries `[ "read" "write" ]`,
  # which has no repeat (removal is the identity on it) and is already ascending (a union that
  # sorted instead would return it unchanged). Two facet keys whose tag lists OVERLAP, written in
  # non-ascending order, is the smallest fixture on which both halves are visible.
  overlapKs = {
    acap = {
      category = "facet";
      contract = "capability";
      option = facetOpt;
    };
    bcap = {
      category = "facet";
      contract = "capability";
      option = facetOpt;
    };
  };
  overlapReg = mkAspectRegistry {
    keySemantics = overlapKs;
    modules = [
      {
        config.aspects.multi = {
          acap.provides = [
            "write"
            "read"
          ];
          bcap.provides = [
            "read"
            "admin"
          ];
        };
      }
    ];
  };
in
{
  flake.tests.facets.test-holes-of-requirer = {
    expr = genLink.holesOf ks requirer;
    expected = [ "dbreq" ];
  };
  flake.tests.facets.test-provider-has-no-holes = {
    expr = genLink.holesOf ks provider;
    expected = [ ];
  };
  flake.tests.facets.test-provides-union = {
    expr = genLink.providesOf ks provider;
    expected = [
      "read"
      "write"
    ];
  };
  flake.tests.facets.test-requirer-provides-nothing = {
    expr = genLink.providesOf ks requirer;
    expected = [ ];
  };
  # Both halves of the union contract at once: `read` is contributed twice and survives once, and
  # the surviving order is the contribution order rather than the sorted one. The expected value is
  # written out so the arm fails on either half independently — a union that stopped removing
  # repeats answers `[ "write" "read" "read" "admin" ]`, one that sorted answers
  # `[ "admin" "read" "write" ]`, and neither is this list.
  flake.tests.facets.test-provides-union-dedups-in-contribution-order = {
    expr = genLink.providesOf overlapKs overlapReg.config.aspects.multi;
    expected = [
      "write"
      "read"
      "admin"
    ];
  };
  flake.tests.facets.test-contract-flavor = {
    expr = genLink.contractOf ks "dbreq";
    expected = "capability";
  };
  # the facet key stayed an OPTION (not a nested aspect): `provider.dbcap` reads back the { provides }
  # value the aspect set. If the `.option` were missing, `dbcap` would freeform-fall through to a nested
  # ASPECT (a submodule with `.key`/`.name`, no `.provides`) — so this read proves the port worked.
  flake.tests.facets.test-facet-value-is-the-option = {
    expr = provider.dbcap.provides;
    expected = [
      "read"
      "write"
    ];
  };
}
