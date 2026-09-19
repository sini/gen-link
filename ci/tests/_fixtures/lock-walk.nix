# THE LOCK WALKER — what a lock reaches under an input carrying a given label, in three units.
#
# NOT A SUITE. It sits under `_fixtures/` because the tree importer ignores any path containing
# `/_`, so this file is reached only by what imports it and never as a flake module.
#
# ★★★ WHAT IT WALKS, AND WHY THE OBVIOUS INSTRUMENT IS THE WRONG ONE. The question is what is reached
# under an input labelled X, walked from `.root`. The obvious instrument — enumerate lock entries
# whose KEY SPELLING matches X — answers a different question: lock keys carry nix's own `_2`/`_3`
# disambiguation suffixes, so that is an artefact of how the lock file was written down rather than a
# fact about the evaluation.
#
# ★★ THE TWO INSTRUMENTS AGREE AT EVERY REVISION SO FAR TESTED, AND THAT IS THE TRAP RATHER THAN THE
# DEFENCE. Agreement between a correct instrument and an incidental one is what a silently wrong
# instrument looks like right up until the revision where it is not — so the ruled form is used
# because it is the question, not because the other one has been caught disagreeing.
#
# ★★★ AND THE THREE UNITS ARE NOT INTERCHANGEABLE. A caller picks the one its property is stated in,
# and `lock-shape.nix` uses all three against different labels for reasons written there:
#
#   • `distinctUnder` / `countUnder` — DISTINCT NODES. What decides whether two `.lib` values are one
#     value WHEN the library's value depends on more than its source, because two nodes at one
#     revision can still resolve different inputs and so evaluate to different things.
#   • `revsUnder` — DISTINCT LOCKED REVISIONS. What decides whether two `.lib` values are one value
#     when the library is a LEAF: with no inputs, the value is a function of the source alone, so
#     nodes sharing a revision are the same value however many of them the lock writes down. For a
#     leaf the node count is a PROXY and this is the property.
#   • `inputLabelsUnder` — THE INPUTS THOSE NODES THEMSELVES DECLARE. This is what makes the choice
#     above checkable instead of assumed: it is the conjunct a caller asserts to earn `revsUnder`.
#
# ★ THE ROOT GUARD IS NOT DEFENSIVE PROGRAMMING. A walker whose root resolves to nothing walks an
# empty graph and reports ZERO for every label, which reads as "the invariant holds" — a wrongly
# rooted walk is silently green. It therefore fails loudly instead.
{
  lib,
  lock,
}:
let
  rootKey =
    if lock.nodes or { } == { } || !(lock.nodes ? ${lock.root or ""}) then
      throw "lock-walk: `.root` names '${lock.root or "<absent>"}', which is not a node in this lock"
    else
      lock.root;

  # An input value is either a node key (a string) or a FOLLOWS PATH (a list), which is resolved
  # segment by segment from the root — never by looking a name up among the lock's keys.
  resolveInput = v: if builtins.isList v then resolvePath v else v;
  resolvePath = lib.foldl' (k: seg: resolveInput lock.nodes.${k}.inputs.${seg}) rootKey;

  labelledEdgesFrom =
    k:
    let
      inputs = lock.nodes.${k}.inputs or { };
    in
    lib.mapAttrsToList (label: v: {
      inherit label;
      node = resolveInput v;
    }) inputs;

  step =
    st:
    let
      edges = builtins.concatMap labelledEdgesFrom st.frontier;
      reached = lib.unique (map (e: e.node) edges);
    in
    {
      frontier = builtins.filter (n: !(builtins.elem n st.seen)) reached;
      seen = lib.unique (st.seen ++ reached);
      edges = st.edges ++ edges;
    };

  # One round per lock node bounds the breadth-first walk: each round adds at least one unseen node
  # or the frontier empties, so the node count is reachable-set-complete. A self-applying walk would
  # cost one evaluator frame per round and past the call-depth guard would end the evaluation, which
  # `tryEval` does not contain.
  walked =
    lib.foldl'
      (
        st: _:
        let
          next = step st;
        in
        builtins.seq (builtins.deepSeq next next) next
      )
      {
        frontier = [ rootKey ];
        seen = [ rootKey ];
        edges = [ ];
      }
      (builtins.attrNames lock.nodes);

  # The distinct nodes reached under an input carrying `label`, anywhere in the walk. Every unit
  # below is derived from this one list rather than re-deriving the filter, so the three can differ
  # in what they report and never in which nodes they report it over.
  nodesUnder =
    label: lib.unique (map (e: e.node) (builtins.filter (e: e.label == label) walked.edges));

  # ★ A NODE WITH NO `locked.rev` REFUSES RATHER THAN COMPARING AS ABSENT. `x.rev or null` would make
  # every revisionless node equal to every other one, so a lock reaching two such sources would
  # report ONE revision — the wrongly-rooted walk's failure mode entered from a different door, and
  # silently green in exactly the same way. A source with no revision is not a source that shares
  # one.
  revOf =
    label: k:
    lock.nodes.${k}.locked.rev
      or (throw "lock-walk: node '${k}', reached under '${label}', carries no `locked.rev`; a source with no revision cannot be compared to another, and reading its absence as a shared revision would collapse every such node into one. Count this label in nodes (`countUnder`) or give the input a revisioned source.");
in
{
  inherit nodesUnder;
  # The distinct nodes reached under an input carrying `label`, anywhere in the walk.
  distinctUnder = nodesUnder;
  countUnder = label: builtins.length (nodesUnder label);

  # The distinct LOCKED REVISIONS of those nodes. For a leaf library this is the instance count the
  # invariant is about; for a library with inputs it is a lower bound and `countUnder` is the unit.
  revsUnder = label: lib.unique (map (revOf label) (nodesUnder label));

  # The input labels those nodes THEMSELVES declare, unioned. `[ ]` says every node reached under
  # `label` is a leaf — the conjunct under which `revsUnder` is a statement about the VALUE and not
  # only about the source.
  inputLabelsUnder =
    label:
    lib.unique (
      builtins.concatMap (k: builtins.attrNames (lock.nodes.${k}.inputs or { })) (nodesUnder label)
    );
}
