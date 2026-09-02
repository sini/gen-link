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

  # ★ THE STRIP'S PREMISE, asserted rather than assumed. `stripComments` cuts each line at a comment
  # marker, and that cut is sound only while the `#` it cuts at stands OUTSIDE a string literal.
  # Where it does not, live code is truncated to the end of that line and every cell below goes
  # blind on what was removed, with no signal at all — a green suite over source nothing scanned.
  #
  # The predicate asks the strip ITSELF where it cut: `stripComments` of a single line is exactly
  # the text before that line's cut. It then asks whether that text closed every double quote it
  # opened, an odd count meaning the cut stands inside a string. Deriving it from `stripComments`
  # rather than restating the cut rule is what keeps premise and strip from drifting apart when one
  # of them is edited, and it is why one block serves both strip families in this ecosystem.
  #
  # It is LINE-LOCAL and so cannot conclude about string content that spans lines — an indented
  # multi-line string block. Those files are declared as a list of their own by
  # `test-strip-premise-multiline-strings` rather than trusted in silence.
  countQuotes = s: (lib.length (lib.splitString "\"" s)) - 1;
  cutIsInString =
    line:
    let
      kept = stripComments line;
    in
    kept != line && lib.mod (countQuotes kept) 2 == 1;

  # premiseBreaches : [ { name; text; } ] -> [ "file:line" ]. A breach is reported at its line as
  # well as its file, because what it says is that one particular line's code was truncated.
  premiseBreaches =
    srcs:
    lib.concatMap (
      src:
      lib.concatLists (
        lib.imap1 (i: line: lib.optional (cutIsInString line) "${src.name}:${toString i}") (
          lib.splitString "\n" src.text
        )
      )
    ) srcs;

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

  # ★ THE READ AND THE STRIP ARE SEPARATE STAGES, one `readFile` per file feeding both. The premise
  # cell has to speak about the RAW text, which is only a value once the strip stops happening inside
  # the read; and `sources` is then a total per-element function of `rawSources` — the name passes
  # through, the code is the strip of the text — so pinning either one pins the other, and the cells
  # over each COMPOSE instead of hoping two independent reads of the same tree agree.
  raw =
    entries:
    map (e: {
      inherit (e) name;
      text = builtins.readFile e.path;
    }) entries;

  strip =
    entries:
    map (e: {
      inherit (e) name;
      code = stripComments e.text;
    }) entries;

  rawSources = raw (walk "lib/" libDir) ++ [
    {
      name = "flake.nix";
      text = builtins.readFile ../../flake.nix;
    }
    {
      name = "default.nix";
      text = builtins.readFile ../../default.nix;
    }
  ];

  sources = strip rawSources;

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
    expr = scan (strip (raw (walk "ci/tests/_fixtures/purity-walk/" ./_fixtures/purity-walk)));
    expected = [
      "ci/tests/_fixtures/purity-walk/nested/tethered.nix: 'lib.'"
      "ci/tests/_fixtures/purity-walk/surface.nix: 'mkOption'"
    ];
  };

  # ★ THE PREMISE HOLDS OF THE TEXT THAT WAS ACTUALLY SCANNED. This is an absence claim over text
  # read from disk and it is NOT non-vacuous on its own: its expectation is `[ ]`, which an emptied
  # or constant subject satisfies exactly as a sound corpus does — a scan of nothing breaches no
  # premise. What arms it is the subject-pinning asserted over this same `rawSources` read, together
  # with the live control below for the predicate itself; green here means the premise holds of the
  # text those cells pin, and nothing more.
  flake.tests.purity.test-strip-premise-holds = {
    expr = premiseBreaches rawSources;
    expected = [ ];
  };

  # And the predicate is capable of saying no. Its subject is a literal written inside this cell
  # rather than anything on disk, so it is UNSEVERABLE from the tree and establishes exactly that the
  # test discriminates an in-string `#` from an ordinary trailing comment — it says nothing whatever
  # about what the cell above was pointed at, and it is NOT that cell's arming. Both directions ride
  # in one expectation: line 1 must be caught and line 2 must not, so a predicate stuck at either
  # constant reds here. The literal cuts under BOTH strip families in this ecosystem — its `#` is
  # whitespace-preceded, so a comment-start strip cuts there too and the control cannot go dead by
  # being pasted into a repository whose strip is the other one.
  flake.tests.purity.test-strip-premise-scan-is-live = {
    expr = premiseBreaches [
      {
        name = "<in-string-hash>";
        text = ''
          url = "a b # c";
          x = 1; # an ordinary trailing comment
        '';
      }
    ];
    expected = [ "<in-string-hash>:1" ];
  };

  # The declared surface: the files the line-local predicate cannot conclude about. An indented
  # multi-line string block carries string content across line boundaries, where a per-line quote
  # count cannot follow it, so those files are written down rather than trusted in silence. The first
  # file to grow one arrives as a red that has to be READ, exactly as a new library file arrives as a
  # red on a membership manifest.
  flake.tests.purity.test-strip-premise-multiline-strings = {
    expr = map (s: s.name) (lib.filter (s: genPrelude.hasInfix "''" s.text) rawSources);
    expected = [ ];
  };
}
