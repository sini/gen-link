# gen-link demo logic — federate two toy collections that both define `apps/media/pg`, wire a
# facet-require in collection B to a capability provider in collection A, and read the diffable
# resolution manifest. A function of the constructed libs; both ./flake.nix and the ci test apply it.
{
  genLink,
  aspects,
  merge,
}:
let
  # facet options MUST be declared (decision 2 / Fix 2): a raw slot carrying { provides|requires }.
  facetOpt = merge.mkOption {
    type = merge.types.raw;
    default = null;
  };
  keySemantics = {
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

  # Build an aspect registry from config modules (local mkReg — the demo flake has no ci helper).
  mkReg =
    modules:
    let
      schema = aspects.mkAspectSchema { inherit keySemantics; };
    in
    merge.evalModuleTree {
      modules = [
        { options.schema = schema.schemaOption; }
        (schema.mkAspectModule { })
      ]
      ++ modules;
    };

  # Collection A ("a"): a postgres capability provider.
  collectionA = mkReg [
    {
      config.aspects.apps.media.pg = {
        nixos.services.postgresql.enable = true;
        dbcap = {
          provides = [
            "read"
            "write"
          ];
        };
      };
    }
  ];

  # Collection B ("b"): its own same-named pg node + an app requiring a db capability, imported from A.
  collectionB = mkReg [
    {
      config.aspects.apps = {
        media.pg.nixos.services.postgresql.enable = true;
        app = {
          nixos.services.myapp.enable = true;
          dbreq = {
            requires = [ "read" ];
          };
          includes = [ (aspects.keyRef "a/apps/media/pg") ];
        };
      };
    }
  ];

  result = genLink.link {
    sources = [
      {
        registry = collectionA.config.aspects;
        inherit keySemantics;
        origin = [ "a" ];
      }
      {
        registry = collectionB.config.aspects;
        inherit keySemantics;
        origin = [ "b" ];
      }
    ];
    # fill B/app's `dbreq` hole with A's postgres provider (provides read,write ⊇ read).
    wire."b/apps/app".dbreq = "a/apps/media/pg";
  };
in
{
  inherit result;
  inherit (result) manifest;
  report = "gen-link demo: ${toString (builtins.length result.manifest)} cross-origin edge(s) bound";
}
