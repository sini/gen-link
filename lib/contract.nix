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
    door: r:
    let
      inherit (r) edgeName provides requires;
      providesRecord = record.fromAttrs (prelude.genAttrs provides (_: true));
      missing = builtins.filter (t: !(record.has t providesRecord)) requires;
    in
    if missing == [ ] then
      record.assertSatisfies requires providesRecord
    else
      throw "${door}: edge '${edgeName}' fails capability — provider missing required tag(s): ${builtins.concatStringsSep ", " missing} (provides: ${builtins.concatStringsSep ", " provides})";

  # refined: delegate to checkRefinements; a non-empty violation list is a loud error.
  refined =
    door: r:
    let
      inherit (r) edgeName refinedType value;
      violations = schema.checkRefinements edgeName refinedType value;
    in
    if violations == [ ] then
      value
    else
      throw "${door}: edge '${edgeName}' fails refinement — ${
        builtins.concatStringsSep "; " (map (v: v.message) violations)
      }";

  # Both published doors take a data RECORD (every field required), so a missing field is refused by
  # name and an extra one admitted (R5), catchably — the native formals refused both past `tryEval`.
  # The check is forced by the result's own condition, at the call.
  checkCapability =
    args:
    capability "gen-link.checkCapability" (
      prelude.checkRequired "gen-link.checkCapability" [
        "edgeName"
        "provides"
        "requires"
      ] args
    );
  checkRefined =
    args:
    refined "gen-link.checkRefined" (
      prelude.checkRequired "gen-link.checkRefined" [
        "edgeName"
        "refinedType"
        "value"
      ] args
    );
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
