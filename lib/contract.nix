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
  checkCapability =
    {
      edgeName,
      provides,
      requires,
    }:
    let
      providesRecord = record.fromAttrs (prelude.genAttrs provides (_: true));
      missing = builtins.filter (t: !(record.has providesRecord t)) requires;
    in
    if missing == [ ] then
      record.assertSatisfies providesRecord requires
    else
      throw "gen-link.contract: edge '${edgeName}' fails capability — provider missing required tag(s): ${builtins.concatStringsSep ", " missing} (provides: ${builtins.concatStringsSep ", " provides})";

  # refined: delegate to checkRefinements; a non-empty violation list is a loud error.
  checkRefined =
    {
      edgeName,
      refinedType,
      value,
    }:
    let
      violations = schema.checkRefinements edgeName refinedType value;
    in
    if violations == [ ] then
      value
    else
      throw "gen-link.contract: edge '${edgeName}' fails refinement — ${builtins.concatStringsSep "; " (map (v: v.message) violations)}";
in
{
  inherit checkCapability checkRefined;
  # exposed for tests: the record `has` predicate.
  _recordHas = record.has;
}
