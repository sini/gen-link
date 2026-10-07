{
  genLink,
  aspects,
  mkAspectRegistry,
  ...
}:
let
  reg = mkAspectRegistry {
    keySemantics.nixos = {
      category = "class";
    };
    modules = [
      (
        { config, ... }:
        {
          config.aspects = {
            helper.nixos = { };
            main = {
              nixos = { };
              includes = [
                config.aspects.helper
                (aspects.keyRef "y/apps/media/pg")
              ];
            };
          };
        }
      )
    ];
  };
  norm = genLink.normalize reg.config.aspects;
  stamped = genLink.originStamp { } [ "x" ] norm;
  # The identifiers are written as LITERALS rather than derived from the library, which is the whole
  # claim: a vertex name is now the readable origin-qualified reference, so a cell can spell it. A
  # cell deriving them from the same constructor the relabel uses would agree with any constructor.
  mainId = "x/main";
  helperId = "x/helper";
  yTargetId = "y/apps/media/pg";

  # A SECOND, ISOLATED fixture: an inline includes entry with no key and no keyRef. gen-aspects'
  # module system synthesizes a key for any bare attrset placed in `includes` regardless of what the
  # author wrote there ("orphan/includes/0"), so this same shape also covers a named-but-wrong-key
  # entry (`{ key = "nonexistent-key"; }` collapses to it too — the synthesized key overrides the
  # authored one). Kept OUT of `reg`/`norm`/`stamped` above: a dangling edge refuses the WHOLE
  # `originStamp` call, not just the vertex a cell is looking at, so nesting it into the shared
  # `main`/`helper` fixture collaterally breaks unrelated cells that force the same `stamped`.
  regDangling = mkAspectRegistry {
    keySemantics.nixos = {
      category = "class";
    };
    modules = [
      {
        config.aspects.orphan = {
          nixos = { };
          includes = [ { } ];
        };
      }
    ];
  };
  normDangling = genLink.normalize regDangling.config.aspects;
  stampedDangling = genLink.originStamp { } [ "x" ] normDangling;

  # A BARE-STRING includes entry (den-hoag-zxgan): the same by-key edge shape as by-value, so a
  # sound one names an edge and a dangling one refuses through the SAME `rewrite.originStamp`
  # lookup as `regDangling` above — no new refusal code. Two isolated fixtures for the same reason
  # `regDangling` is isolated: a dangling edge refuses the whole `originStamp` call.
  regBareStringSound = mkAspectRegistry {
    keySemantics.nixos = {
      category = "class";
    };
    modules = [
      {
        config.aspects = {
          sibling.nixos = { };
          bystr = {
            nixos = { };
            includes = [ "sibling" ];
          };
        };
      }
    ];
  };
  normBareStringSound = genLink.normalize regBareStringSound.config.aspects;
  stampedBareStringSound = genLink.originStamp { } [ "x" ] normBareStringSound;

  regBareStringDangling = mkAspectRegistry {
    keySemantics.nixos = {
      category = "class";
    };
    modules = [
      {
        config.aspects.orphanstr = {
          nixos = { };
          includes = [ "no-such-sibling" ];
        };
      }
    ];
  };
  normBareStringDangling = genLink.normalize regBareStringDangling.config.aspects;
  stampedBareStringDangling = genLink.originStamp { } [ "x" ] normBareStringDangling;
in
{
  flake.tests.rewrite.test-vertices-are-identifiers = {
    expr = builtins.elem mainId stamped.graph.vertices && builtins.elem helperId stamped.graph.vertices;
    expected = true;
  };
  flake.tests.rewrite.test-byvalue-edge-relabeled = {
    expr = builtins.any (e: e.from == mainId && e.to == helperId) stamped.graph.edges;
    expected = true;
  };
  # The by-key edge relabels to the target's identifier read from the keyRef's OWN origin, never the
  # assigned one (decision 6) — `y`, not the `x` this source was stamped with.
  flake.tests.rewrite.test-bykey-edge-cross-origin = {
    expr = builtins.any (e: e.from == mainId && e.to == yTargetId) stamped.graph.edges;
    expected = true;
  };
  flake.tests.rewrite.test-idtonode-carries-origin = {
    expr = stamped.idToNode.${mainId}.origin;
    expected = [ "x" ];
  };
  # alias genuinely re-names the vertex: the OLD helper identifier must be gone and a new one present.
  flake.tests.rewrite.test-alias-changes-identifier = {
    expr =
      let
        aliased = genLink.originStamp {
          alias = {
            helper = "helper-renamed";
          };
        } [ "x" ] norm;
        oldGone = !(builtins.elem helperId aliased.graph.vertices);
        newAppeared = builtins.any (v: !(builtins.elem v stamped.graph.vertices)) aliased.graph.vertices;
      in
      {
        inherit oldGone newAppeared;
      };
    expected = {
      oldGone = true;
      newAppeared = true;
    };
  };
  # two sources aliasing the SAME source path to DIFFERENT names must not collide.
  flake.tests.rewrite.test-alias-no-collision = {
    expr =
      let
        s1 = genLink.originStamp {
          alias = {
            helper = "helper-one";
          };
        } [ "x" ] norm;
        s2 = genLink.originStamp {
          alias = {
            helper = "helper-two";
          };
        } [ "x" ] norm;
        h1 = builtins.filter (v: !(builtins.elem v stamped.graph.vertices)) s1.graph.vertices;
        h2 = builtins.filter (v: !(builtins.elem v stamped.graph.vertices)) s2.graph.vertices;
      in
      (builtins.head h1) != (builtins.head h2);
    expected = true;
  };
  # A local includes entry naming a key absent from BOTH `nodesByKey` and `refByToken` must refuse by
  # name (ADR-0016 ruling 5), catchably — not abort past `tryEval` as an interpreter "attribute
  # missing". The message-content half of this claim (that the refusal names the entry) lives in
  # `ci/tests-error.nix`, where `nix-unit`'s `expectedError` — not `tryEval`, which discards the
  # thrown text — is the assertion for a claim about a message.
  flake.tests.rewrite.test-dangling-includes-refuses-by-name = {
    expr = (builtins.tryEval (builtins.deepSeq stampedDangling.graph.vertices "ok")).success;
    expected = false;
  };
  # A BARE-STRING includes entry names a by-key edge — the SAME shape as the by-value case above
  # (`test-byvalue-edge-relabeled`), not a new one: `sibling` relabels to `x/sibling` exactly as
  # `helper` relabels to `x/helper`.
  flake.tests.rewrite.test-barestring-edge-relabeled = {
    expr = builtins.any (
      e: e.from == "x/bystr" && e.to == "x/sibling"
    ) stampedBareStringSound.graph.edges;
    expected = true;
  };
  # A bare-string includes entry naming no sibling key refuses through the SAME lookup as
  # `regDangling` (an anonymous `{ }`) — no new refusal code, per the spec.
  flake.tests.rewrite.test-barestring-dangling-refuses-by-name = {
    expr = (builtins.tryEval (builtins.deepSeq stampedBareStringDangling.graph.vertices "ok")).success;
    expected = false;
  };
  # The ordinary fixture never sees the dangling one — a fixture-isolation regression would show up
  # here as a broken orphan check on `stamped`, not as this cell just staying green by accident.
  flake.tests.rewrite.test-orphan-does-not-shadow-a-real-node = {
    expr = builtins.tryEval (
      builtins.elem mainId stamped.graph.vertices && builtins.elem helperId stamped.graph.vertices
    );
    expected = {
      success = true;
      value = true;
    };
  };
}
