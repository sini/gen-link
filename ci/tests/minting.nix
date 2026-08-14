# THE SEAM — what `link` gets from delegating minting to the staged entry, asserted on the results a
# consumer reads. The cells whose subject is a refusal MESSAGE live in `../tests-error.nix`.
{
  lib,
  genLink,
  genMerge,
  mkAspectRegistry,
  ...
}:
let
  fixtures = import ./_fixtures/link.nix { inherit genLink genMerge mkAspectRegistry; };
  inherit (fixtures) wired;

  holeRows = res: builtins.filter (e: e.kind == "hole") res.manifest;
  endpoints =
    res:
    builtins.concatMap (e: [
      e.from
      e.to
    ]) res.manifest;

  twoLabels = genLink.link fixtures.twoLabels;
  chain = genLink.link fixtures.chain;
  brokenCycle = genLink.link fixtures.brokenCycle;
in
{
  # ── EVERY NODE IS AN EMITTER ──
  # Not a design preference: a relatum resolves only against the frozen set, and the only door into
  # that set is emission — so a node that could be named as a filler must be minted, and any node
  # can be named. A relatum-free provider therefore carries an identity exactly as a wired requirer
  # does.
  flake.tests.minting.test-every-merged-node-carries-an-identity = {
    expr = builtins.all (
      id: (wired.nodes.${id} ? identity) && lib.hasPrefix "aspect:" wired.nodes.${id}.identity
    ) (builtins.attrNames wired.nodes);
    expected = true;
  };
  # The node map is keyed by the readable coordinate, which is the half of ADR-0016 ruling 5 this
  # library used to collapse: it keyed the graph by a content-address, so a node's name and a node's
  # identity were two values of one type with no name for the difference.
  # Every enumerated node, including the intermediate path nodes a registry tree contributes, and
  # each under the coordinate a reader would write to name it.
  flake.tests.minting.test-the-node-map-is-keyed-by-identifier = {
    expr = builtins.attrNames wired.nodes;
    expected = [
      "a/apps"
      "a/apps/media"
      "a/apps/media/pg"
      "b/apps"
      "b/apps/app"
    ];
  };

  # ── THE LABEL IS THE TRAVERSAL TOKEN ──
  # ADR-0024 as amended makes the string that keys the identity the same string an incident edge
  # carries, so choosing a label is choosing a traversal token. `hole:` named the MECHANISM rather
  # than the relation, and it is retired: there is no compatibility argument for keeping it, because
  # the migration moves every identity under either spelling.
  flake.tests.minting.test-a-hole-row-carries-the-bare-facet-label = {
    expr = map (e: {
      inherit (e) from to via;
    }) (holeRows wired);
    expected = [
      {
        from = "b/apps/app";
        to = "a/apps/media/pg";
        via = "dbreq";
      }
    ];
  };
  flake.tests.minting.test-two-holes-emit-two-rows-with-distinct-labels = {
    expr = lib.sort (a: b: a < b) (map (e: e.via) (holeRows twoLabels));
    expected = [
      "cachereq"
      "dbreq"
    ];
  };
  # Two holes filled by ONE provider are two relata, so the requirer's identity is a function of
  # both labels — the rows are not a rendering of a single edge counted twice.
  flake.tests.minting.test-two-labels-key-one-identity = {
    expr = twoLabels.nodes."b/apps/app".identity == wired.nodes."b/apps/app".identity;
    expected = false;
  };

  # ── THE MANIFEST CARRIES IDENTIFIERS ──
  # ADR-0016 ruling 5 rules the derived content-address INTERNAL ADDRESSING ONLY: consistent within
  # an evaluation, with nothing durable depending on it across them. This record is designed for a
  # consumer to serialize to a `gen-link.lock`, so a row carrying an identity would be exactly the
  # durable cross-evaluation dependence the ruling forbids. The identifiers ARE the readable
  # coordinates, and the identity rebuilds from the rows.
  flake.tests.minting.test-every-manifest-endpoint-is-a-node-map-key = {
    expr = builtins.all (p: wired.nodes ? ${p}) (endpoints wired);
    expected = true;
  };
  flake.tests.minting.test-no-manifest-row-carries-an-identity = {
    expr = builtins.any (p: lib.hasPrefix "aspect:" p) (endpoints twoLabels);
    expected = false;
  };

  # ── THE PASS IS DERIVED, AND IT GENUINELY STAGES ──
  # A three-deep chain links only if the derivation assigns three distinct passes: `m`'s relatum `p`
  # has to be frozen before `m` mints, and a scheme emitting everything at pass 0 leaves it unfrozen
  # and refuses. So this cell fails under the degenerate assignment rather than merely being
  # satisfied by it.
  flake.tests.minting.test-a-three-deep-chain-stages = {
    expr = lib.sort (a: b: a < b) (map (e: "${e.from}<-${e.to}") (holeRows chain));
    expected = [
      "b/m<-a/p"
      "c/q<-b/m"
    ];
  };
  # The pass is a function of the wire GRAPH, so it is invariant under the order the sources and the
  # wire entries were presented in — by construction rather than by an author's discipline. A
  # user-declared index would be invariant only if every author got it right.
  flake.tests.minting.test-identities-are-invariant-under-presentation-order = {
    expr =
      let
        reversed = genLink.link (
          fixtures.chain
          // {
            sources = lib.reverseList fixtures.chain.sources;
          }
        );
      in
      builtins.mapAttrs (_: n: n.identity) reversed.nodes;
    expected = builtins.mapAttrs (_: n: n.identity) chain.nodes;
  };

  # ── THE CYCLE'S CONTROL ──
  # The refusal cells next door mean nothing beside a fixture that cannot link at all: the same two
  # nodes with the cycle broken link green, so what the refusal reports is the cycle and not the
  # fixture.
  flake.tests.minting.test-the-same-nodes-link-with-the-cycle-broken = {
    expr = map (e: e.via) (holeRows brokenCycle);
    expected = [ "dbreq" ];
  };
}
