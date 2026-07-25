{
  description = "gen-link demo: federate two aspect collections across origins";

  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";
    gen-merge.url = "github:sini/gen-merge";
    gen-aspects.url = "github:sini/gen-aspects";
    gen-link.url = "github:sini/gen-link";
  };

  outputs =
    {
      gen-merge,
      gen-aspects,
      gen-link,
      ...
    }:
    let
      demo = import ./demo.nix {
        genLink = gen-link.lib;
        aspects = gen-aspects.lib;
        merge = gen-merge.lib;
      };
    in
    {
      # `nix eval ./examples/demo#report` or `nix eval ./examples/demo#manifest --json`.
      inherit (demo) manifest report;
      lib.demo = demo;
    };
}
