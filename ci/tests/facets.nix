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
