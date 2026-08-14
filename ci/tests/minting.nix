# THE SEAM — what `link` gets from delegating minting to the staged entry, asserted on the results a
# consumer reads. The cells whose subject is a refusal MESSAGE live in `../tests-error.nix`.
{
  lib,
  genLink,
  genMerge,
  aspects,
  mkAspectRegistry,
  ...
}:
let
  fixtures = import ./_fixtures/link.nix {
    inherit
      genLink
      genMerge
      aspects
      mkAspectRegistry
      ;
  };
  inherit (fixtures) wired;

  holeRows = res: builtins.filter (e: e.kind == "hole") res.manifest;
  endpoints =
    res:
    builtins.concatMap (e: [
      e.from
      e.to
    ]) res.manifest;
  # Every string a row carries, so an "identities never serialize" claim quantifies over the whole
  # row rather than over the two fields someone remembered to list.
  allRowStrings =
    res: builtins.concatMap (e: builtins.filter builtins.isString (builtins.attrValues e)) res.manifest;

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

  # ── EACH ENDPOINT CARRIES ITS NODE'S KIND ──
  # An identity is `"<kind>:" + digest`, so the kind is the tag prefix and nothing else in a row
  # carries it once the identity stops being serialized. A consumer holding a row of a mixed-kind
  # federation would otherwise have no way to name the kind to mint with, and the
  # identity-rebuilds-from-the-rows property would hold only for a single-kind one.
  #
  # ★ The fields are NOT called `kind`: this row already has one, and it means the ROW's sort
  # (`"includes"` / `"hole"`) — a property of the relation rather than of either endpoint.
  flake.tests.minting.test-every-row-carries-both-endpoint-kinds = {
    expr = map (e: {
      inherit (e) kind fromKind toKind;
    }) wired.manifest;
    expected = [
      # `"hole"` precedes `"includes"` because `order` sorts on the row kind first.
      {
        kind = "hole";
        fromKind = "aspect";
        toKind = "aspect";
      }
      {
        kind = "includes";
        fromKind = "aspect";
        toKind = "aspect";
      }
    ];
  };
  # The kind is READ from the minting run rather than defaulted: `entry` takes both as REQUIRED
  # formals. The cell measures the SIGNATURE rather than trying to catch the refusal, because a
  # missing required formal is an EVALUATOR arity error and `tryEval` does not contain one — the
  # same class of abort as calling a library entry with a formal it does not supply. `functionArgs`
  # reports `false` for a formal with no default, so this says exactly which fields a caller may
  # omit: `via` alone.
  flake.tests.minting.test-both-endpoint-kinds-are-required-formals = {
    expr = builtins.functionArgs genLink.entry;
    expected = {
      kind = false;
      from = false;
      fromKind = false;
      to = false;
      toKind = false;
      via = true;
    };
  };
  flake.tests.minting.test-a-row-is-built-from-identifiers-and-kinds = {
    expr = genLink.entry {
      kind = "hole";
      from = "a/x";
      fromKind = "aspect";
      to = "b/y";
      toKind = "aspect";
      via = "dbreq";
    };
    expected = {
      kind = "hole";
      from = "a/x";
      fromKind = "aspect";
      to = "b/y";
      toKind = "aspect";
      via = "dbreq";
    };
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
  # Quantified over EVERY string field of every row, not only the endpoints — the endpoint kinds are
  # bare kind names (`"aspect"`), and an identity would be the same name followed by a colon and a
  # digest, so the predicate has to be able to tell those apart on any field.
  flake.tests.minting.test-no-manifest-row-carries-an-identity = {
    expr = builtins.any (p: lib.hasPrefix "aspect:" p) (allRowStrings twoLabels);
    expected = false;
  };
  # CONTROL for the predicate above: it fires on a value that IS an identity, so the `false` is a
  # measurement rather than a predicate that could not have matched.
  flake.tests.minting.test-CONTROL-the-identity-predicate-fires = {
    expr = lib.hasPrefix "aspect:" twoLabels.nodes."b/apps/app".identity;
    expected = true;
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
