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
  # A wrong-typed origin is REFUSED, catchably (den-hoag-bkdkg); before the guard each aborted past
  # `tryEval`, crashing this cell. The message is pinned in `ci/tests-error.nix`. The last two arms
  # are the controls.
  flake.tests.ref.test-wrong-typed-origin-refused-catchably = {
    expr =
      map
        (
          { who, origin }:
          (builtins.tryEval (genLink.${who} origin)).success
        )
        [
          {
            who = "originLabel";
            origin = { };
          }
          {
            who = "originLabel";
            origin = [ { } ];
          }
          {
            who = "renderOrigin";
            origin = { };
          }
          {
            who = "renderOrigin";
            origin = "y";
          }
          {
            who = "originLabel";
            origin = [ "y" ];
          }
          {
            who = "renderOrigin";
            origin = [ "y" ];
          }
        ];
    expected = [
      false
      false
      false
      false
      true
      true
    ];
  };
  # The guards sit in the bodies, so the doors stay plain lambdas: a wrapper that made one a functor
  # set would make `functionArgs` abort here.
  flake.tests.ref.test-origin-doors-are-plain-lambdas = {
    expr = map builtins.functionArgs [
      genLink.originLabel
      genLink.renderOrigin
    ];
    expected = [
      { }
      { }
    ];
  };
}
