# The closed doors' shared checks (den-hoag-7gp66 P1): each takes `prelude.checkOptions` /
# `prelude.checkRequired` rather than native closed formals, which refused a missing or unknown field
# past `tryEval`. Catchability is asserted here; each message is pinned on the real path in
# `ci/tests-error.nix` (`doors`).
#
# `entry`'s native formals are the subject of `minting.test-both-endpoint-kinds-are-required-formals`,
# a `functionArgs` assertion, so it keeps them with an ellipsis: an unknown field is refused by name,
# and a missing required one is still the evaluator's abort (not asserted here: `tryEval` cannot).
{
  genLink,
  aspects,
  mkAspectRegistry,
  genMerge,
  ...
}:
let
  # WHNF only: each door forces its check at the call, so the refusal meets the caller there.
  caught = e: (builtins.tryEval e).success;
  fixtures = import ./_fixtures/link.nix {
    inherit
      genLink
      genMerge
      aspects
      mkAspectRegistry
      ;
  };
  cap = {
    edgeName = "e";
    provides = [ "read" ];
    requires = [ "read" ];
  };
  refined = {
    edgeName = "e";
    refinedType = null;
    value = 1;
  };
  norm = genLink.normalize { };
  stamp = {
    normalized = norm;
    origin = [ "x" ];
  };
  src = builtins.head fixtures.sources;
  entryArgs = {
    kind = "hole";
    from = "a/x";
    fromKind = "aspect";
    to = "b/y";
    toKind = "aspect";
  };
in
{
  # Two RECORD doors: a missing field refused, an extra one admitted (R5).
  flake.tests.doors.test-check-capability = {
    expr = {
      valid = caught (genLink.checkCapability cap);
      extraAdmitted = caught (genLink.checkCapability (cap // { notAField = 1; }));
      missingRefused = !(caught (genLink.checkCapability (removeAttrs cap [ "requires" ])));
      nonSetRefused = !(caught (genLink.checkCapability 1));
    };
    expected = {
      valid = true;
      extraAdmitted = true;
      missingRefused = true;
      nonSetRefused = true;
    };
  };
  flake.tests.doors.test-check-refined = {
    expr = {
      valid = caught (genLink.checkRefined refined);
      extraAdmitted = caught (genLink.checkRefined (refined // { notAField = 1; }));
      missingRefused = !(caught (genLink.checkRefined (removeAttrs refined [ "value" ])));
    };
    expected = {
      valid = true;
      extraAdmitted = true;
      missingRefused = true;
    };
  };

  # Two MIXED doors: required fields and options, the whole set closed. Each result is a record, so
  # WHNF of the call is exactly what must carry the refusal.
  flake.tests.doors.test-origin-stamp = {
    expr = {
      valid = caught (genLink.originStamp stamp);
      withAlias = caught (genLink.originStamp (stamp // { alias = { }; }));
      missingRefused = !(caught (genLink.originStamp { normalized = norm; }));
      unknownRefused = !(caught (genLink.originStamp (stamp // { notAnOption = 1; })));
      badOriginRefused = !(caught (genLink.originStamp (stamp // { origin = "x"; })));
    };
    expected = {
      valid = true;
      withAlias = true;
      missingRefused = true;
      unknownRefused = true;
      badOriginRefused = true;
    };
  };
  flake.tests.doors.test-link = {
    expr = {
      valid = caught (genLink.link { sources = [ ]; });
      withWire = caught (
        genLink.link {
          sources = [ ];
          wire = { };
        }
      );
      missingRefused = !(caught (genLink.link { wire = { }; }));
      unknownRefused =
        !(caught (
          genLink.link {
            sources = [ ];
            notAnOption = 1;
          }
        ));
      # A source record: `registry` required, the rest closed.
      sourceMissingRefused = !(caught (genLink.link { sources = [ (removeAttrs src [ "registry" ]) ]; }));
      sourceUnknownRefused = !(caught (genLink.link { sources = [ (src // { notAnOption = 1; }) ]; }));
      sourceBadOriginRefused = !(caught (genLink.link { sources = [ (src // { origin = "a"; }) ]; }));
    };
    expected = {
      valid = true;
      withWire = true;
      missingRefused = true;
      unknownRefused = true;
      sourceMissingRefused = true;
      sourceUnknownRefused = true;
      sourceBadOriginRefused = true;
    };
  };

  flake.tests.doors.test-entry = {
    expr = {
      valid = caught (genLink.entry entryArgs);
      withVia = caught (genLink.entry (entryArgs // { via = "dbreq"; }));
      unknownRefused = !(caught (genLink.entry (entryArgs // { notAnOption = 1; })));
    };
    expected = {
      valid = true;
      withVia = true;
      unknownRefused = true;
    };
  };

  # B2 (b): `wire` takes identifiers. A declaration filler — the provider's own aspect value — is
  # refused by name as `gen-link.link`; the same filler as its identifier links.
  flake.tests.doors.test-wire-declaration-refused = {
    expr = {
      identifier = caught (
        builtins.deepSeq (fixtures.linkManifest { wire."b/apps/app".dbreq = "a/apps/media/pg"; }) true
      );
      declaration = caught (
        builtins.deepSeq (fixtures.linkManifest {
          wire."b/apps/app".dbreq = src.registry.apps.media.pg;
        }) true
      );
    };
    expected = {
      identifier = true;
      declaration = false;
    };
  };

  # den-hoag-7gp66 P1 residue: three pre-existing UNCATCHABLE aborts reached through `link`, each now
  # a NAMED, catchable refusal (message pinned in `ci/tests-error.nix`'s `doors`) — or, for the
  # structured filler, simply no longer forced through a raw-value string interpolation at all.
  flake.tests.doors.test-link-residue = {
    expr = {
      # (1) keyRef's own malformed-reference-string refusal, reached through a `wire` KEY, named
      # `gen-link.link` rather than `gen-aspects.keyRef` (R6).
      malformedWireKeyRefused =
        !(caught (builtins.deepSeq (fixtures.linkManifest { wire."///".dbreq = "a/apps/media/pg"; }) true));
      # (2a) a structured `{ origin; path; }` filler used to abort inside `"${filler}"` (edgeName's
      # string interpolation) whenever the contract check forced it. On the SAME satisfying
      # federation the string-filler form links, it no longer even reaches that branch.
      structuredFillerLinks = caught (
        builtins.deepSeq (fixtures.linkManifest {
          wire."b/apps/app".dbreq = {
            origin = [ "a" ];
            path = [
              "apps"
              "media"
              "pg"
            ];
          };
        }) true
      );
      # (2b) a non-list `sources`.
      nonListSourcesRefused = !(caught (genLink.link { sources = "not-a-list"; }));
      # (2c) a non-set `wire.<requirerRef>`.
      wireEntryNonSetRefused =
        !(caught (
          builtins.deepSeq
            (genLink.link {
              inherit (fixtures) sources;
              wire."b/apps/app" = "not-a-set";
            }).manifest
            true
        ));
    };
    expected = {
      malformedWireKeyRefused = true;
      structuredFillerLinks = true;
      nonListSourcesRefused = true;
      wireEntryNonSetRefused = true;
    };
  };
}
