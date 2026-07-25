{ genLink, ... }:
{
  flake.tests.smoke.test-lib-evaluates = {
    expr = genLink._scaffold;
    expected = true;
  };
}
