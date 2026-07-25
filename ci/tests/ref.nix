{ genLink, ... }:
{
  flake.tests.ref.test-self-maps-to-empty-origin = {
    expr =
      let
        r = genLink.parseRef "self/postgres";
      in
      {
        inherit (r) origin path key;
      };
    expected = {
      origin = [ ];
      path = [ "postgres" ];
      key = "postgres";
    };
  };
  flake.tests.ref.test-named-origin-string = {
    expr =
      let
        r = genLink.parseRef "y/apps/media/pg";
      in
      {
        inherit (r) origin key;
      };
    expected = {
      origin = [ "y" ];
      key = "apps/media/pg";
    };
  };
  flake.tests.ref.test-structured-normalizes = {
    expr =
      let
        r = genLink.parseRef {
          origin = [ "y" ];
          path = [
            "apps"
            "pg"
          ];
        };
      in
      {
        inherit (r) origin key;
      };
    expected = {
      origin = [ "y" ];
      key = "apps/pg";
    };
  };
  flake.tests.ref.test-origin-label-and-render = {
    expr = {
      emptyLabel = genLink.originLabel [ ];
      yLabel = genLink.originLabel [ "y" ];
      emptyRender = genLink.renderOrigin [ ];
    };
    expected = {
      emptyLabel = "";
      yLabel = "y";
      emptyRender = "self";
    };
  };
}
