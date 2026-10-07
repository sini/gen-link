# Facet contract type-check (design §facet: facets TYPE edges, never resolve them). Per ACTIVE edge:
# capability -> gen-algebra `record.assertSatisfies` (Bracha & Cook 1990 provide/require; requires ⊆
# provides, after list -> record); refined value -> gen-schema `checkRefinements` (Findler 2002 / Rondon
# 2008). gen-link READS the tags and SEQUENCES the check; satisfaction is the sibling's. A failure is a
# LOUD, named error at the edge.
{
  prelude,
  algebra,
  schema,
}:
let
  inherit (algebra) record;

  # capability: turn the provides LIST into a record (tags -> marker fields -> record.fromAttrs), then
  # call record.assertSatisfies (which returns the record or throws). gen-link pre-computes `missing`
  # only to name the edge in the error; on success assertSatisfies IS the arbiter (load-bearing).
  # `door` is the published door the caller invoked, which the refusal names first (R6): the export
  # below, or `gen-link.link` for the edges `link` checks.
  capability =
    door: edgeName: requires: provides:
    let
      providesRecord = record.fromAttrs (prelude.genAttrs provides (_: true));
      missing = builtins.filter (t: !(record.has t providesRecord)) requires;
    in
    if missing == [ ] then
      record.assertSatisfies requires providesRecord
    else
      throw "${door}: edge '${edgeName}' fails capability — provider missing required tag(s): ${builtins.concatStringsSep ", " missing} (provides: ${builtins.concatStringsSep ", " provides})";

  # refined: delegate to checkRefinements; a non-empty violation list is a loud error.
  refined =
    door: edgeName: refinedType: value:
    let
      violations = schema.checkRefinements edgeName refinedType value;
    in
    if violations == [ ] then
      value
    else
      throw "${door}: edge '${edgeName}' fails refinement — ${
        builtins.concatStringsSep "; " (map (v: v.message) violations)
      }";

  # Both published doors are POSITIONAL (den-hoag-7gp66 P2, rule 4): their arity is structural and no
  # record check remains. Each takes the edge name, then the contract, then the subject, which is the
  # order of the authority it sequences: `checkRefined edgeName refinedType value` is gen-schema's
  # `checkRefinements fieldPath type value`, and `checkCapability edgeName requires provides` is
  # gen-algebra's `record.assertSatisfies required r` behind the name. The subject is what the door
  # checks and returns (the filler's value; the provider's tags, as their record), so a check applied
  # to a name and a contract is a predicate over providers. The name and the contract are two
  # configuration operands WITH a natural order, the authority's own, so the keyed-record ruling does
  # not reach them.
  checkCapability = capability "gen-link.checkCapability";
  checkRefined = refined "gen-link.checkRefined";
in
{
  inherit
    capability
    refined
    checkCapability
    checkRefined
    ;
  # exposed for tests: the record `has` predicate.
  _recordHas = record.has;
}
