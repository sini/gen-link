# THE DOOR CHECKS (den-hoag-7gp66 P2 — `prelude.door`, R7 argument structure / R5 field closure) —
# every published step of gen-link that takes a RECORD catches its own violations, at its own
# application, catchably.
#
# After P2 a door step is one of two kinds (spec §p2.3.1):
#   · an OPTIONS step — one closed set, first in the call: `link { wire ?; } sources`,
#     `originStamp { alias ?; } origin normalized` and `entry { via ?; } …`;
#   · a RECORD step — open, all fields required (R5), behind its options step and guarded by it
#     (`optionsStep`, G10): `entry`'s `{ kind; from; fromKind; to; toKind; }` (rule 5 (b): a row
#     constructor names no subject, and `from`/`to` are one sort with no natural order).
# `checkCapability edgeName requires provides` and `checkRefined edgeName refinedType value` are
# positional (rule 4): their arity is structural and they carry no row. Each source in `link`'s list
# is a data element, not a door step, and keeps its closed check.
#
# WHICH refusal fired is a claim about the message and `tryEval` yields only `success`; the byte
# goldens naming each door (R6) live in `ci/tests-error.nix`'s `flake.testsError.doors`.
{
  genLink,
  genPrelude,
  aspects,
  mkAspectRegistry,
  genMerge,
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
  src = builtins.head fixtures.sources;
  norm = genLink.normalize src.registry;

  # `firesAtApplication` forces the step's application to WHNF only — never `deepSeq` — so a check
  # that ran only behind a later field read reads `false` (spec §p2.5, premise 5).
  firesAtApplication = e: !(builtins.tryEval (builtins.seq e null)).success;
  answers = e: (builtins.tryEval (builtins.deepSeq e null)).success;

  row = {
    kind = "hole";
    from = "a/x";
    fromKind = "aspect";
    to = "b/y";
    toKind = "aspect";
  };

  # The options rows: the door, its options, `apply` supplying the operands after the options step,
  # and one non-default option whose value the door's own result carries (G3), read by `observe`.
  optionsRows = {
    link = {
      optional = [ "wire" ];
      apply = f: f fixtures.sources;
      # The requirer declares one hole: with `wire` filling it the federation binds that node, and
      # without it the completeness guard refuses the call. Both are answers of the door's own result,
      # read through `tryEval`, so the `{ }` control answers too.
      observe =
        r:
        let
          t = builtins.tryEval (builtins.deepSeq r.bound (map (b: b.identifier) r.bound));
        in
        if t.success then t.value else "refused: a hole left unwired";
      opt.wire."b/apps/app".dbreq = "a/apps/media/pg";
    };
    originStamp = {
      optional = [ "alias" ];
      apply = f: f [ "x" ] norm;
      observe = r: r.graph.vertices;
      opt.alias."apps/media/pg" = "apps/media/postgres";
    };
    entry = {
      optional = [ "via" ];
      apply = f: f row;
      observe = r: r.via;
      opt.via = "dbreq";
    };
  };

  # The record step behind each chained options step: the step `{ }` forms, its required fields, and
  # one complete record it answers on.
  recordRows = {
    entry = {
      step = genLink.entry { };
      required = [
        "kind"
        "from"
        "fromKind"
        "to"
        "toKind"
      ];
      good = row;
    };
  };

  # A field name no door declares, generated per evaluation from the door names themselves, so it is
  # never a name any contract below lists.
  stranger = "not-a-field-of-" + builtins.concatStringsSep "-" (builtins.attrNames optionsRows);

  perOptions = f: builtins.mapAttrs f optionsRows;
  perRecord = f: builtins.mapAttrs f recordRows;

  surfaceDoors = builtins.attrNames (
    genPrelude.filterAttrs (
      _: v:
      let
        t = builtins.tryEval (builtins.isAttrs v && v ? __functor && v ? __contract);
      in
      t.success && t.value
    ) genLink
  );
in
{
  flake.tests.doors = {
    # ── LIVE CONTROLS, first: the predicates are not dead ──
    test-control-firesAtApplication-is-true-for-an-ordinary-throw = {
      expr = firesAtApplication (throw "control probe, not this suite's subject");
      expected = true;
    };
    test-control-firesAtApplication-is-false-for-a-throw-behind-an-unread-field = {
      expr = firesAtApplication { culprit = throw "control probe, not this suite's subject"; };
      expected = false;
    };

    # ── THE TABLE IS THE SURFACE ──
    # Every published door has a row and every row is a published door, so a door added without a
    # row — or a row whose door reverted to a lambda — reds here.
    test-the-door-table-equals-the-surface-doors = {
      expr = surfaceDoors;
      expected = builtins.sort (a: b: a < b) (builtins.attrNames optionsRows);
    };
    test-the-positional-checks-are-plain-lambdas = {
      expr = map (n: builtins.isFunction genLink.${n}) [
        "checkCapability"
        "checkRefined"
      ];
      expected = [
        true
        true
      ];
    };
    # The positional checks answer, and refuse on the contract they sequence (the edge name, then the
    # contract, then the subject).
    test-the-positional-checks-answer-and-refuse = {
      expr = {
        capabilityHolds = answers (genLink.checkCapability "e" [ "read" ] [ "read" ]);
        capabilityRefused = firesAtApplication (genLink.checkCapability "e" [ "admin" ] [ "read" ]);
        # The order is load-bearing: nothing required of a provider of `admin` holds, and the same two
        # lists swapped (`admin` required of a provider of nothing) refuse.
        orderedHolds = answers (genLink.checkCapability "e" [ ] [ "admin" ]);
        swappedRefused = firesAtApplication (genLink.checkCapability "e" [ "admin" ] [ ]);
        refinedValue = genLink.checkRefined "e" null 1;
      };
      expected = {
        capabilityHolds = true;
        capabilityRefused = true;
        orderedHolds = true;
        swappedRefused = true;
        refinedValue = 1;
      };
    };

    # ── OPTIONS STEPS ──
    # G1/G4: an unknown option is refused at `f opts`'s WHNF, before any operand.
    test-an-unknown-option-is-refused-at-the-options-application = {
      expr = perOptions (n: _: firesAtApplication (genLink.${n} { ${stranger} = 1; }));
      expected = perOptions (_: _: true);
    };
    test-a-non-set-options-argument-is-refused-at-the-application = {
      expr = perOptions (n: _: firesAtApplication (genLink.${n} 1));
      expected = perOptions (_: _: true);
    };
    # The old one-record shape is refused by name at its first application: its fields are not
    # options of the door.
    test-the-old-one-record-shape-is-refused-at-the-application = {
      expr = {
        link = firesAtApplication (genLink.link { inherit (fixtures) sources; });
        originStamp = firesAtApplication (
          genLink.originStamp {
            normalized = norm;
            origin = [ "x" ];
          }
        );
        entry = firesAtApplication (genLink.entry row);
      };
      expected = perOptions (_: _: true);
    };
    # The live control: `{ }` forms the door and the operands answer.
    test-control-the-empty-options-answer = {
      expr = perOptions (n: r: answers (r.observe (r.apply (genLink.${n} { }))));
      expected = perOptions (_: _: true);
    };
    # Every option of each door is admitted, together.
    test-every-option-is-admitted = {
      expr = perOptions (
        n: r: !firesAtApplication (genLink.${n} (genPrelude.genAttrs r.optional (_: null)))
      );
      expected = perOptions (_: _: true);
    };
    # D3: the published contract and the functor-aware reader agree with the row.
    test-each-options-door-publishes-its-contract = {
      expr = perOptions (
        n: _: {
          inherit (genLink.${n}.__contract) optional open required;
          args = genPrelude.functionArgs genLink.${n};
        }
      );
      expected = perOptions (
        _: r: {
          inherit (r) optional;
          open = false;
          required = [ ];
          args = builtins.listToAttrs (map (f: genPrelude.nameValuePair f true) r.optional);
        }
      );
    };
    # G3: a non-default option reaches the result (`differ`, against `{ }`), and the partially
    # applied door agrees with the full call (`agree`), each read from its own evaluation.
    test-a-non-default-option-reaches-the-result = {
      expr = perOptions (
        n: r:
        let
          f1 = genLink.${n} r.opt;
          run = f: r.observe (r.apply f);
        in
        {
          agree = run f1 == run (genLink.${n} r.opt);
          differ = run f1 != run (genLink.${n} { });
        }
      );
      expected = perOptions (
        _: _: {
          agree = true;
          differ = true;
        }
      );
    };
    # Composition: `originStamp opts origin` is a value mapped over subgraphs.
    test-a-partially-applied-door-maps-over-subgraphs = {
      expr =
        let
          stampX = genLink.originStamp { } [ "x" ];
        in
        map (s: builtins.length (stampX s).graph.vertices) [
          norm
          (genLink.normalize { })
        ];
      expected = [
        (builtins.length (builtins.attrNames norm.nodesByKey))
        0
      ];
    };

    # ── RECORD STEPS (R5: open, all fields required) ──
    # D2: a missing required field is refused at the record's application, before any field read.
    test-each-missing-required-field-is-refused-at-the-application = {
      expr = perRecord (
        _: r: map (f: firesAtApplication (r.step (builtins.removeAttrs r.good [ f ]))) r.required
      );
      expected = perRecord (_: r: map (_: true) r.required);
    };
    # G2 / G10-ctl: an extra field is admitted, answer unchanged (R5's stated price).
    test-an-extra-field-is-admitted-and-the-answer-is-unchanged = {
      expr = perRecord (_: r: r.step (r.good // { ${stranger} = 1; }) == r.step r.good);
      expected = perRecord (_: _: true);
    };
    # G10: an option of the step's own options door, given on the record instead, is refused by name
    # at the record's application rather than silently ignored.
    test-an-option-given-on-the-record-is-refused-at-the-record-application = {
      expr = perRecord (
        n: r: map (o: firesAtApplication (r.step (r.good // { ${o} = null; }))) optionsRows.${n}.optional
      );
      expected = perRecord (n: _: map (_: true) optionsRows.${n}.optional);
    };
    # D3: the record step's contract is published, and the options step names it as its next.
    test-each-record-step-publishes-its-contract = {
      expr = perRecord (
        n: r: {
          inherit (r.step.__contract) required open;
          next = genLink.${n}.__contract.next == r.step.__contract;
        }
      );
      expected = perRecord (
        _: r: {
          inherit (r) required;
          open = true;
          next = true;
        }
      );
    };

    # ── `link`'s SOURCES, the subject: each a closed data element ──
    test-link-sources = {
      expr = {
        nonListRefused = firesAtApplication (genLink.link { } "not-a-list");
        sourceMissingRefused = firesAtApplication (genLink.link { } [ (removeAttrs src [ "registry" ]) ]);
        sourceUnknownRefused = firesAtApplication (genLink.link { } [ (src // { notAnOption = 1; }) ]);
        sourceBadOriginRefused = firesAtApplication (genLink.link { } [ (src // { origin = "a"; }) ]);
        badOriginRefused = firesAtApplication (genLink.originStamp { } "x" norm);
      };
      expected = {
        nonListRefused = true;
        sourceMissingRefused = true;
        sourceUnknownRefused = true;
        sourceBadOriginRefused = true;
        badOriginRefused = true;
      };
    };

    # B2 (b): `wire` takes identifiers. A declaration filler — the provider's own aspect value — is
    # refused by name as `gen-link.link`; the same filler as its identifier links.
    test-wire-declaration-refused = {
      expr = {
        identifier = answers (fixtures.linkManifest { wire."b/apps/app".dbreq = "a/apps/media/pg"; });
        declaration = answers (
          fixtures.linkManifest { wire."b/apps/app".dbreq = src.registry.apps.media.pg; }
        );
      };
      expected = {
        identifier = true;
        declaration = false;
      };
    };

    # den-hoag-7gp66 P1 residue: three pre-existing UNCATCHABLE aborts reached through `link`, each
    # now a NAMED, catchable refusal (message pinned in `ci/tests-error.nix`'s `doors`) — or, for the
    # structured filler, simply no longer forced through a raw-value string interpolation at all.
    test-link-residue = {
      expr = {
        # (1) keyRef's own malformed-reference-string refusal, reached through a `wire` KEY, named
        # `gen-link.link` rather than `gen-aspects.keyRef` (R6).
        malformedWireKeyRefused =
          !(answers (fixtures.linkManifest { wire."///".dbreq = "a/apps/media/pg"; }));
        # (2a) a structured `{ origin; path; }` filler used to abort inside `"${filler}"` (edgeName's
        # string interpolation) whenever the contract check forced it. On the SAME satisfying
        # federation the string-filler form links, it no longer even reaches that branch.
        structuredFillerLinks = answers (
          fixtures.linkManifest {
            wire."b/apps/app".dbreq = {
              origin = [ "a" ];
              path = [
                "apps"
                "media"
                "pg"
              ];
            };
          }
        );
        # (2c) a non-set `wire.<requirerRef>`.
        wireEntryNonSetRefused =
          !(answers (genLink.link { wire."b/apps/app" = "not-a-set"; } fixtures.sources).manifest);
      };
      expected = {
        malformedWireKeyRefused = true;
        structuredFillerLinks = true;
        wireEntryNonSetRefused = true;
      };
    };
  };
}
