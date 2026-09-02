# Purity invariant (gen-prelude design §5): gen-link's library source is nixpkgs-lib-free — no
# `lib.foo` / `lib.types` / `evalModules`, and no `nixpkgs` input. This pins "pure" as a checked
# property, not an aspiration — a stray tether creeping back into the library source fails CI.
#
# ★ WHAT THIS SUITE SAYS, AND WHAT IT DOES NOT. gen-link declares SEVERAL gen-* sibling inputs —
# `flake.lock` is the roster, not this line — and no `nixpkgs` one. The scan covers the root
# `flake.nix`, so the `nixpkgs` ban is what holds that second half. It says NOTHING about those
# siblings' own purity; each library asserts its own, in its own suite.
#
# Scope: every `.nix` file under `lib/`, at any depth + the root flake.nix + default.nix (the
# library + its flake). NOT ci/ — the test harness legitimately uses nixpkgs.lib (including, here,
# to do this scan).
{ genPrelude, lib, ... }:
let
  libDir = ../../lib;

  # Drop each line from the `#` that STARTS A COMMENT — one at the start of the line, or preceded
  # by whitespace. A `#` flush against other text is inside a string literal (lib/link.nix builds
  # an edge name that way), and cutting there hides every character after it — code included —
  # from the scan below. The rule this replaces cut at the FIRST `#` and rested on "no `#` in a
  # string literal", which is false in this corpus and was asserted by nothing.
  #
  # Where the rule cannot tell, it KEEPS the text, and that direction is the whole point: prose
  # that gets scanned is a red CI somebody reads, code that goes unscanned is nothing at all. It
  # still cuts at a whitespace-preceded `#` inside a `''…''` block — measured absent here, and the
  # residue a full Nix lexer would close.
  stripComments =
    text:
    let
      stripLine =
        line:
        let
          parts = lib.splitString "#" line;
          step =
            acc: part:
            if acc.done then
              acc
            else if acc.text == "" || lib.hasSuffix " " acc.text || lib.hasSuffix "\t" acc.text then
              acc // { done = true; }
            else
              acc // { text = acc.text + "#" + part; };
        in
        (lib.foldl' step {
          text = lib.head parts;
          done = false;
        } (lib.tail parts)).text;
    in
    lib.concatStringsSep "\n" (map stripLine (lib.splitString "\n" text));

  # walk : string -> path -> [ { name; path; } ], `name` being `prefix` extended by the entry's
  # position in the tree. The flat `readDir` this replaces filtered on `.nix` and so dropped a
  # SUBDIRECTORY on the floor: a tether under `lib/sub/` was invisible to a cell named
  # `…-is-nixpkgs-lib-free`, measured green with the file present and git-tracked. Same shape as
  # gen-graph's, deliberately — the walk cell below is its fixture too.
  walk =
    prefix: dir:
    lib.concatLists (
      lib.mapAttrsToList (
        entry: type:
        if type == "directory" then
          walk "${prefix}${entry}/" (dir + "/${entry}")
        else if lib.hasSuffix ".nix" entry then
          [
            {
              name = "${prefix}${entry}";
              path = dir + "/${entry}";
            }
          ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  read =
    entries:
    map (e: {
      inherit (e) name;
      code = stripComments (builtins.readFile e.path);
    }) entries;

  sources = read (walk "lib/" libDir) ++ [
    {
      name = "flake.nix";
      code = stripComments (builtins.readFile ../../flake.nix);
    }
    {
      name = "default.nix";
      code = stripComments (builtins.readFile ../../default.nix);
    }
  ];

  # Tokens that signal a nixpkgs-lib tether or the module-system (Korora-class) tier.
  forbidden = [
    "nixpkgs" # a nixpkgs flake input / reference
    "lib." # any nixpkgs lib call (lib.types, lib.genAttrs, …)
    "{ lib }" # the old `{ lib }` parameter signature
    "{ lib," # `{ lib, … }` parameter signature
    "evalModules" # module-system tier
    "mkOption" # module-system tier
  ];

  scan =
    srcs:
    lib.concatMap (
      src:
      map (tok: "${src.name}: '${tok}'") (lib.filter (tok: genPrelude.hasInfix tok src.code) forbidden)
    ) srcs;

  # A synthetic line carrying BOTH halves of the strip's job at once, and NOT written to disk, so
  # the invariant cell stays a statement about the real library. `lib.types.str` sits after a `#`
  # that is inside a string literal: it must SURVIVE and be found. `nixpkgs` sits after a real
  # trailing comment marker: it must be DROPPED and not found.
  probe = {
    name = "<in-string-hash>";
    code = stripComments "edgeName = \"a#b\"; x = lib.types.str; # nixpkgs, in a trailing comment";
  };
in
{
  flake.tests.purity.test-library-source-is-nixpkgs-lib-free = {
    expr = scan sources;
    expected = [ ];
  };

  # THE STRIP IS THE OPERAND OF THE CELL ABOVE, exercised here at an input that cell never reads.
  # The `[ ]` above is a claim about code only if the strip discards comments and nothing else, and
  # a strip that cut at the first `#` would produce that same `[ ]` while hiding the tail of four
  # real lines across the sibling libraries. Both halves are asserted by the one expected value:
  # `lib.` present says the in-string `#` did not truncate, its absence of `nixpkgs` says the
  # trailing comment still went.
  flake.tests.purity.test-control-strip-cuts-at-comments-not-inside-strings = {
    expr = scan [ probe ];
    expected = [ "<in-string-hash>: 'lib.'" ];
  };

  # THE WALK DESCENDS, AND CARRIES ITS PREFIX. lib/ is flat today, so the invariant cell exercises
  # the recursive branch not at all and would keep passing if the walk quietly flattened — which is
  # precisely the state this replaced. The fixture tree is nested on purpose and carries a planted
  # tether at each of its two depths; handing the walk a non-empty prefix pins both halves of the
  # naming rule, that the given prefix is threaded through and that a subdirectory's prefix extends
  # it rather than replacing it.
  flake.tests.purity.test-walk-descends-into-subdirectories = {
    expr = scan (read (walk "ci/tests/_fixtures/purity-walk/" ./_fixtures/purity-walk));
    expected = [
      "ci/tests/_fixtures/purity-walk/nested/tethered.nix: 'lib.'"
      "ci/tests/_fixtures/purity-walk/surface.nix: 'mkOption'"
    ];
  };
}
