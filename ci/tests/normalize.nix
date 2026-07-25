{
  genLink,
  aspects,
  mkAspectRegistry,
  ...
}:
let
  reg = mkAspectRegistry {
    keySemantics.nixos = {
      category = "class";
    };
    modules = [
      (
        { config, ... }:
        {
          config.aspects = {
            helper.nixos = { };
            main = {
              nixos = { };
              includes = [
                config.aspects.helper # by-value
                (aspects.keyRef "y/apps/media/pg") # by-key
              ];
            };
          };
        }
      )
    ];
  };
  norm = genLink.normalize reg.config.aspects;
  keys = builtins.sort builtins.lessThan (builtins.attrNames norm.nodesByKey);
in
{
  flake.tests.normalize.test-nodes-enumerated = {
    expr = keys;
    expected = [
      "helper"
      "main"
    ];
  };
  flake.tests.normalize.test-byvalue-edge = {
    expr = builtins.any (e: e.from == "main" && e.to == "helper") norm.edges;
    expected = true;
  };
  flake.tests.normalize.test-bykey-edge-tokenized = {
    expr = builtins.any (e: e.from == "main" && genLink._hasRefPrefix e.to) norm.edges;
    expected = true;
  };
  flake.tests.normalize.test-refbytoken-records-origin = {
    expr =
      let
        tok = builtins.head (builtins.filter genLink._hasRefPrefix (map (e: e.to) norm.edges));
      in
      norm.refByToken.${tok}.origin;
    expected = [ "y" ];
  };
}
