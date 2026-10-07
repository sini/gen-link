{
  genLink,
  genSchema,
  genMerge,
  ...
}:
let
  ok =
    genLink.checkCapability "e1"
      [ "read" ]
      [
        "read"
        "write"
      ];
  bad = builtins.tryEval (genLink.checkCapability "e2" [ "admin" ] [ "read" ]);
  # a refined facet: value must be a valid tcp port.
  portType = genSchema.refined genMerge.types.int genSchema.refinements.tcpPort;
  refOk = genLink.checkRefined "e3" portType 5432;
  refBad = builtins.tryEval (genLink.checkRefined "e4" portType 99999);
in
{
  flake.tests.contract.test-capability-satisfied-returns-record = {
    expr = genLink._recordHas "read" ok && genLink._recordHas "write" ok;
    expected = true;
  };
  flake.tests.contract.test-capability-unsatisfied-throws = {
    expr = bad.success;
    expected = false;
  };
  flake.tests.contract.test-refined-passes = {
    expr = refOk;
    expected = 5432;
  };
  flake.tests.contract.test-refined-fails = {
    expr = refBad.success;
    expected = false;
  };
}
