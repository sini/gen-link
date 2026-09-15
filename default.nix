# Standalone (non-flake) entry. Flake consumers should use the `.lib` output.
#
# gen-link is Class B: gen-prelude base + {gen-scope, gen-view, gen-schema, gen-algebra,
# gen-aspects}.
#
# THREE CHANNELS, ONE PRECEDENCE, AND NONE OF THEM IS A PROBE. A named formal per dependency wins;
# the `inputs` bag is next, tested by attrset membership so a supplied-but-throwing value throws as
# ITSELF rather than falling back; the default is resolved from `./ci/flake.lock`, read as local
# data. There is NO `...`: an argument this root does not declare is a loud error, not a silent drop.
#
# THE PIN SOURCE IS `ci/flake.lock`, NOT THE ROOT `flake.lock`. The root lock stays the flake path's
# lock and is no longer read by Nix code, which is what lets one rule hold across the roster: a root
# lock exists only where the root flake declares inputs, while `ci/flake.lock` exists everywhere —
# including at the libraries that declare no inputs at all and so could hold no shim under the old
# rule. All six dependencies are root inputs of the ci lock, so every path below is one segment.
#
# `src` AND `dep` ARE FORMALS, NOT `let` BINDINGS, AND THAT IS THE INJECTABLE RESOLVER SEAM — the
# one channel a cell can close. `src` is the only expression here that fetches; everything else
# reads the lock as data. A caller supplying `src = segs: throw "…"` therefore makes fetching
# IMPOSSIBLE for that application rather than merely absent, which is what `ci/tests/entry.nix`
# rests on. A `dep` bound in the `let` below would close over the `let`'s `src`, so the override
# would silently do nothing and the shim would fetch anyway, at rc 0.
#
# THE HAND-WRITTEN THREADING IS GONE, AND WHAT REPLACES IT IS PIN COHERENCE RATHER THAN DATAFLOW.
# This shim used to pass its own `prelude`/`schema` down into gen-scope and gen-schema so that one
# evaluator over one authority served both — two instances being two content-address formulas for
# one node. Coherent `ci/flake.lock` pins resolve to one store path and `import` memoises, so there
# is no second instance for a threading to collapse. What makes the count one is now the PINS, and
# the roster-wide coherence check that keeps them coherent is the hub's rather than this file's.
#
# The `let` is OUTSIDE the lambda because a formal's default is evaluated in the FORMAL scope, which
# does not see a `let` in the body.
let
  lock = builtins.fromJSON (builtins.readFile ./ci/flake.lock);
  inputsOf = node: lock.nodes.${node}.inputs or { };
  # A direct edge IS the node key; a `follows` value is a PATH resolved segment by segment from this
  # lock's own root. Never by indexing `lock.nodes.<label>` — a last-segment shortcut reads a
  # different node.
  following =
    node: inp:
    let
      v = (inputsOf node).${inp};
    in
    if builtins.isString v then v else builtins.foldl' following lock.root v;
  fetch = segs: builtins.foldl' following lock.root segs;
in
{
  inputs ? { },
  src ? segs: "${builtins.fetchTree lock.nodes.${fetch segs}.locked}",
  # Arity dispatch, because a dependency's root is a function at a shim'd library and a bare value
  # at a leaf, and neither `import p` nor `import p { }` is total over both.
  dep ?
    segs:
    let
      v = import (src segs);
    in
    if builtins.isFunction v then v { } else v,
  # `wire` IS THE THIRD SEAM, AND IT IS WHAT MAKES THE ENTRY SUITE'S HERMETIC CELL EXPRESSIBLE AT
  # ALL. Nix publishes WHETHER a formal has a default and never WHAT it is, so the only place a
  # formal NAME and its resolved PATH are both in scope is this file's argument to `./lib`. `wire`
  # exposes exactly that attrset and nothing else: a cell injecting `dep = segs: segs` alongside
  # `wire = args: args` reads this shim's own formal-to-path map, with nothing fetched and no path
  # restated by hand. It is a widening and so breaks no caller — there is no `...` here, and no
  # caller passes a name this root does not declare.
  wire ? args: import ./lib args,
  prelude ? inputs.gen-prelude or (dep [ "gen-prelude" ]),
  scope ? inputs.gen-scope or (dep [ "gen-scope" ]),
  view ? inputs.gen-view or (dep [ "gen-view" ]),
  schema ? inputs.gen-schema or (dep [ "gen-schema" ]),
  algebra ? inputs.gen-algebra or (dep [ "gen-algebra" ]),
  aspects ? inputs.gen-aspects or (dep [ "gen-aspects" ]),
}:
# THE BODY IS EAGER, AND THAT IS WHAT MAKES THE ENTRY CELL TOTAL RATHER THAN PARTIAL. `forced` forces
# every wired dependency to WHNF before `./lib` sees it, so a default that cannot resolve is loud AT
# THE BOUNDARY rather than wherever a consumer first reaches an attribute. Without it a force of this
# root reaches only the dependencies the published surface happens to be derived from — and
# `builtins.deepSeq` cannot make up the difference, because it does not enter a lambda. Measured at
# this library, the roster's widest: a pure force of the landed body reached 2 of its 6 dependency
# paths and read green over the other four. With the eager body a WHNF force of the root reaches all
# six, whatever the published surface's shape.
#
# THE FORCE STOPS AT WHNF DELIBERATELY: `builtins.seq` of an attrset does not force its members, so
# this reaches each dependency's root VALUE and never a member of it. A library that deliberately
# refuses to build some member is therefore not an exception to it.
let
  deps = {
    inherit
      prelude
      scope
      view
      schema
      algebra
      aspects
      ;
  };
  forced = builtins.deepSeq (builtins.mapAttrs (_: builtins.typeOf) deps) null;
in
builtins.seq forced (wire deps)
