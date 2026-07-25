{
  genLink,
  genSchema,
  ...
}:
let
  ok = genLink.checkCapability {
    edgeName = "e1";
    provides = [
      "read"
      "write"
    ];
    requires = [ "read" ];
  };
  bad = builtins.tryEval (
    genLink.checkCapability {
      edgeName = "e2";
      provides = [ "read" ];
      requires = [ "admin" ];
    }
  );
  # a refined facet: value must be a valid tcp port.
  portType = genSchema.refined genSchema.types.int genSchema.refinements.tcpPort;
  refOk = genLink.checkRefined {
    edgeName = "e3";
    refinedType = portType;
    value = 5432;
  };
  refBad = builtins.tryEval (
    genLink.checkRefined {
      edgeName = "e4";
      refinedType = portType;
      value = 99999;
    }
  );
in
{
  flake.tests.contract.test-capability-satisfied-returns-record = {
    expr = genLink._recordHas ok "read" && genLink._recordHas ok "write";
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
