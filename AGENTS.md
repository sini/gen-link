# gen-link — agent capability sheet

## Scope

Cross-flake aspect federation: `link { sources, wire }` normalizes each source aspect registry into an origin-free includes-graph, stamps every node with a federation origin, disjoint-unions the subgraphs, binds facet holes into instantiation identity, and returns a diffable resolution manifest — owning only the origin coordinate, the union-with-relabel, and the manifest, and delegating every computation to a gen sibling.

## Not this library's job

Quoted text is the owner's own `flake.nix` `description` field, verbatim.

| Responsibility | Owner |
|---|---|
| Hashing an identity (`hashIdentity`), refined types, `checkRefinements` | `gen-schema` — "gen-schema: typed record registry with extension points for the pure-gen module system". gen-link calls `hashIdentity` and never `sha256` (`lib/identity.nix:23,54`) |
| Aspect payload, the `keySemantics` grammar, `aspectId`, `keyRef` slash-splitting | `gen-aspects` — "gen-aspects: aspect-oriented composition types (pure-gen, re-hosted on gen-merge)". `parseRef` owns only the `self` ⟷ `[]` surface mapping (`lib/ref.nix:5-6`) |
| Algebraic-graph `overlay` / `gmap` / `vertices` / `edges`, and the scope evaluator (`buildNodes`, `eval`) | `gen-scope` — "gen-scope: demand-driven attribute grammar evaluator over algebraic scope graphs" |
| Resolving an edge (forward `includes` nearest-binding) | `gen-resolve` — "gen-resolve — demand-driven higher-order RAG evaluator over algebraic scope graphs (Knuth 1968 attribute schedule + Vogt 1989 HOAG)" |
| Materialization — moving class content into a class evaluation | `gen-edge` — "gen-edge — the content-movement contract: the (S,T,P,M) edge algebra, toposorted materialization fold, and the frozen edge-trace parity oracle". `gen-edge` is a declared input (`flake.nix:11`) that `lib/**` never imports; it is exercised only by `ci/tests/conductor-oracle.nix` |
| Record algebra, capability satisfaction (`record.has` / `record.assertSatisfies`) | `gen-algebra` — "gen-algebra: pure Nix algebra — search monad, records, intensional functions, either" |
| General utilities (gen-link is nixpkgs-lib-free; `flake.nix:4-6`) | `gen-prelude` — "gen-prelude: vendored, nixpkgs-lib-free pure utilities for the gen ecosystem" |
| Module merge, `evalModuleTree`, `mkOption` — building the aspect registry gen-link ingests | `gen-merge` — "gen-merge — pure-Nix byte-mode module MERGE engine (evalModuleTree) for the pure-gen module system". Not a gen-link input; it is a `ci/flake.nix:5` input only |
| Reachability, condensation, visibility queries over the merged graph | `gen-graph` — "gen-graph: accessor-based graph query combinators". Named in `README.md:42,64`; not a gen-link input (`flake.nix:7-15`) |
| Dataflow channels — the `pipe.channel` homonym, distinct from a keySemantics channel (`README.md:258`) | `gen-pipe` — "gen-pipe — scoped channels + dataflow algebra (map/filter/fold/scan/route/join/tee) with B5 determinism, provenance, dedup, and class-aware contributions" |
| Any domain vocabulary (NixOS / home-manager / den keys) | the consuming flake — every facet and class key arrives as a per-source `keySemantics` parameter (`lib/link.nix:44-51`; `README.md:9`) |
| Serializing the manifest to disk (a `gen-link.lock`) | the consuming flake — `lib/manifest.nix:3-4` states gen-link writes nothing |

## Consumer surface

Sweep of all 126 `flake.nix` files under `/home/sini/Documents/repos` (depth 6) for `gen-link.url`: two declarations.

| Consumer | Evidence |
|---|---|
| `gen` (the ecosystem hub) | `gen/flake.nix:35` declares the input; `gen/lib/mkGenLibs.nix:34` re-exports it as `link` |
| `gen-link/examples/demo` | `examples/demo/flake.nix:8` |

`den-hoag` does **not** declare gen-link. Its root `flake.nix:5-23` lists nineteen `gen-*` inputs and gen-link is not among them; gen-link reaches `den-hoag/ci/flake.lock` only transitively, through the hub declared at `den-hoag/ci/flake.nix:3` and `den-hoag/parity/flake.nix:5`. `git grep gen-link` over den-hoag excluding `.beads`/`*.jsonl` returns 8 hits — 4 lockfile lines and 4 comments (`ci/tests/namespace-origin-identity.nix:3`, `lib/compat/namespace.nix:84`, `lib/identity-preimage.nix:15-16`) that name gen-link's `nodeId` as the formula reference while reaching the content-address through gen-aspects `aspectId` directly. Positive control on the same predicate and scope: `gen-scope` ⇒ 145 hits. No den-hoag `.nix` file calls a gen-link export; the 13 `\.link\b` hits in den-hoag `*.nix` are its own `declare.link` API, an unrelated homonym.

## Exports

Entry: `inputs.gen-link.lib` (flake), or `gen.lib.link` through the hub. Root `default.nix` is a **function** — `import ./gen-link { }` — whose named parameters (`prelude`, `scope`, `resolve`, `edge`, `schema`, `algebra`, `aspects`) default to the `flake.lock` pins and may each be overridden.

**References & origin** — `lib/ref.nix`

| Export | Signature |
|---|---|
| `parseRef` | `ref -> { __keyRef; origin; path; key }` (string sugar or structured `{ origin; path }`; `self` ⇒ origin `[]`) |
| `originLabel` | `origin -> string` — the `"/"`-joined list; the datum `hashIdentity` hashes |
| `renderOrigin` | `origin -> string` — surface rendering; `[]` ⇒ `"self"` |

**Identity** — `lib/identity.nix`

| Export | Signature |
|---|---|
| `nodeId` | `origin -> node -> id` (delegates to gen-aspects `aspectId`) |
| `keyRefTargetId` | `parsedRef -> id` (hashes the keyRef's own `origin` + `key`) |
| `instantiatedId` | `origin -> node -> holeFillings -> id` (empty fillings ≡ `nodeId`; facet keys sorted before hashing) |

**Federation steps** — `lib/normalize.nix`, `lib/rewrite.nix`, `lib/union.nix`

| Export | Signature |
|---|---|
| `normalize` | `registry -> { nodesByKey; edges; refByToken }` |
| `_hasRefPrefix` | `string -> bool` (tests the `"@ref:"` token prefix) |
| `originStamp` | `{ normalized, origin, alias ? {} } -> { graph; idToNode }` |
| `disjointUnion` | `[ { graph; idToNode } ] -> { graph; idToNode }` |

**Facets & contracts** — `lib/facets.nix`, `lib/contract.nix`

| Export | Signature |
|---|---|
| `holesOf` | `ks -> node -> [facet]` (facet keys whose value carries `requires`) |
| `providesOf` | `ks -> node -> [tag]` |
| `requiresOf` | `node -> facet -> [tag]` |
| `contractOf` | `ks -> facet -> "capability" \| "refined"` |
| `checkCapability` | `{ edgeName, provides, requires } -> record \| throw` |
| `checkRefined` | `{ edgeName, refinedType, value } -> value \| throw` |
| `_recordHas` | `record -> tag -> bool` (gen-algebra `record.has`, re-exposed) |

**Wire, manifest, conductor** — `lib/wire.nix`, `lib/manifest.nix`, `lib/link.nix`

| Export | Signature |
|---|---|
| `bindNode` | `{ origin, node, ks, holeFillings } -> { id; node; origin; holeFillings }` |
| `entry` | `{ kind, from, to, via ? null } -> manifestEntry` (`kind` ∈ `{ "includes", "hole" }`) |
| `order` | `[ entry ] -> [ entry ]` (deterministic sort for diff stability) |
| `link` | `{ sources, wire ? {} } -> { graph; manifest; nodes; bound; resolved }` |
| `_scaffold` | `true` (a constant) |

**`link` argument and return shape** (consumed/produced, not exports). Each `sources` entry is `{ registry; origin ? []; alias ? {}; keySemantics ? {}; }`. `wire` is `{ "<requirerRef>" = { <facet> = "<fillerRef>"; }; }`. The return record carries `graph` (the merged gen-scope graph), `manifest` (ordered `{ kind; from; to; via }`), `nodes` (`{ <id> = { origin; node }; }`), `bound` (`[ { id; node; origin; holeFillings } ]`), and `resolved` (`{ <holelessRequirerId> = [tag] | null; }`).

## Entry points by task

| Task | Reach for |
|---|---|
| Federate several registries end to end | `link { sources = […]; wire = {…}; }` |
| Fill a facet-require across the seam | a `wire."<origin>/<key>".<facet> = "<origin>/<key>"` entry |
| Ingest one registry into a graph without federating | `normalize <registry>` |
| Rescope one registry under an origin (or rename its nodes) | `originStamp { normalized; origin; alias; }` |
| Merge already-stamped subgraphs | `disjointUnion [ … ]` |
| Compute a node's federation id | `nodeId <origin> <node>` |
| Compute the id an `@ref` include points at | `keyRefTargetId (parseRef "<origin>/<key>")` |
| Compute the id of a hole-filled instantiation | `instantiatedId <origin> <node> <holeFillings>` — or `bindNode`, which also enforces coverage |
| Read a node's ports | `holesOf` / `providesOf` / `requiresOf` / `contractOf` |
| Type-check one edge by hand | `checkCapability` (tag subset) / `checkRefined` (gen-schema refined type) |
| Turn an origin into a manifest/error string | `renderOrigin` (`[]` ⇒ `"self"`); `originLabel` for the hash preimage |
| Build or sort manifest rows outside `link` | `entry` / `order` |
| Explore the whole surface in a REPL | `nix repl ./ci/repl.nix` — `import ./.. { }` plus nixpkgs `lib` |

## Measured traps

All rows verified in this run at rev `2a4abda` (clean tree). Shared fixture: `genLink = import <repo-root> { }` with `prelude`/`schema`/`aspects` threaded explicitly (siblings from `flake.lock`, `gen-merge` from `ci/flake.lock`); `ks` declares `nixos` as `category = "class"` and `dbcap`/`dbreq` as `category = "facet"`, `contract = "capability"`, each with a declared `merge.types.raw` option; `regA` holds `apps/media/pg` providing `[ "read" "write" ]`; `regB` holds the same path `apps/media/pg` plus `apps/app` requiring `[ "read" ]` and including `keyRef "a/apps/media/pg"`; `srcs` places them at origins `[ "a" ]` / `[ "b" ]`; `wired = link { sources = srcs; wire."b/apps/app".dbreq = "a/apps/media/pg"; }`; `unwired = link { sources = srcs; }`; `T = e: (builtins.tryEval e).success`.

| Trap | Evidence |
|---|---|
| The unwired-hole completeness guard is reachable **only** through `.manifest` — every other field of the same `link` result evaluates fine with a hole left open | `lib/link.nix:206-208`; on `unwired`, `T (deepSeq unwired.graph true)`, `.bound`, `.resolved` ⇒ `true` and `length (attrNames unwired.nodes)` ⇒ `true`, while `T (deepSeq unwired.manifest true)` ⇒ `false`. Positive control, same expression on the wired variant: `T (deepSeq wired.manifest true)` ⇒ `true`. Test: `test-unwired-required-facet-throws` (`ci/tests/link.nix`) |
| A source that omits `keySemantics` silently disables the hole guard for **its own** nodes | `lib/link.nix:45-51` (`ksOf` falls back to `{ }`), `lib/facets.nix:8,15`; with regB's entry lacking `keySemantics`, `T (deepSeq .manifest true)` ⇒ `true` although `b/apps/app` is unwired. `holesOf { } app` ⇒ `[ ]`; positive control, same node: `holesOf ks app` ⇒ `[ "dbreq" ]` |
| `resolved` is keyed by the **holeless** `nodeId`, never by the bound instantiation id | `lib/link.nix:169-174`; `wired.resolved ? (nodeId [ "b" ] app)` ⇒ `true`, `wired.resolved ? (head wired.bound).id` ⇒ `false`, the two ids differ ⇒ `true`, and the value is `[ "read" "write" ]`. Test: `test-resolution-through-gen-resolve` (`ci/tests/link.nix`) |
| A node with no `includes` gets **no** `resolved` entry — absent, not `null` | `lib/link.nix:173` (keys come from `importIndex`, i.e. edge sources only); `wired.resolved ? (nodeId [ "a" ] pgA)` ⇒ `false` while `wired.nodes ? (nodeId [ "a" ] pgA)` ⇒ `true` |
| `bindNode` never checks that a filling names a declared hole — an arbitrary key forks identity silently | `lib/wire.nix:20-29` checks only that declared holes are *covered*; `lib/identity.nix:43-52` hashes whatever keys it is handed. `(bindNode { origin = [ "a" ]; node = pgA; ks; holeFillings.notAFacet = "zzz"; }).id` ⇒ `T` `true` and `!= nodeId [ "a" ] pgA` ⇒ `true`. Positive control: `holeFillings = { }` ⇒ id `==` `nodeId` ⇒ `true` |
| `contractOf` answers for keys that are not facets at all, and never throws | `lib/facets.nix:10`; `contractOf ks "neverDeclared"` ⇒ `"capability"`, and `contractOf ks "nixos"` (a `category = "class"` key) ⇒ `"capability"` |
| `nodeId` ignores the node's `.key` — overriding it is dead; `name` is the live field | `lib/rewrite.nix:38-41` (`aspectId` reads `identity.key` = `pathKey ((meta.aspect-chain or []) ++ [ name ])`); `nodeId [ "a" ] (pgA // { key = "totally/different"; }) == nodeId [ "a" ] pgA` ⇒ `true`. Positive control: `nodeId [ "a" ] (pgA // { name = "renamed"; }) == nodeId [ "a" ] pgA` ⇒ `false` |
| Two sources given the **same** `origin` collapse same-key nodes silently — `idToNode` is folded with `//`, last source wins | `lib/union.nix:12`; stamping regA and regB both at origin `[ "a" ]`, nodes whose `.key` is `apps/media/pg` ⇒ `1`. Positive control at origins `[ "a" ]` / `[ "b" ]` ⇒ `2`. Test (distinct-origin direction only): `test-same-path-distinct-ids` (`ci/tests/union.nix`) |
| `originLabel []` and `renderOrigin []` disagree by design: `""` vs `"self"` | `lib/identity.nix:26,48` hashes the `""` form; `lib/ref.nix:23` and `lib/link.nix:45-51,120` use `"self"` for manifests, errors and the `ksByOrigin` key. Observed `""` / `"self"`. Test: `test-origin-label-and-render` (`ci/tests/ref.nix`) |
| `parseRef "self"` (bare, no slash) yields an **empty** key, not an error; and `self` is special only in first position | `lib/ref.nix:12-17`; `"self"` ⇒ `{ origin = [ ]; key = ""; }`, `"y/self/pg"` ⇒ `{ origin = [ "y" ]; key = "self/pg"; }`. Positive control: `"y/apps/pg"` ⇒ `{ origin = [ "y" ]; key = "apps/pg"; }` |
| An **anonymous inline** `includes` entry becomes a dangling edge that crashes the origin-rewrite with an error `tryEval` cannot catch | gen-aspects coerces `includes = [ { notAKey = 1; } ]` into a full aspect node keyed `main/includes/0`, but `lib/normalize.nix:26-31` strips `includes` before the child scan — so `nodesByKey` ⇒ `[ "main" ]` while `edges` ⇒ `[ { from = "main"; to = "main/includes/0"; } ]`. Forcing `originStamp` on it: `error: attribute '"main/includes/0"' missing` at `lib/rewrite.nix:33:30`, and the surrounding `T (…)` never returns. Positive control: the same expression over a by-value `includes` registry ⇒ `true` |
| Declaring a facet key **without** an `.option` keeps the hole visible but adds a phantom graph node | `lib/normalize.nix:21,26-31`; `README.md:134`. With `dbreq` declared `category = "facet"` and no `option`: `holesOf ksNoOpt app` ⇒ `[ "dbreq" ]` (the freeform fallback still carries `requires`), yet `attrNames (normalize reg).nodesByKey` ⇒ `[ "app" "app/dbreq" ]`. Positive control with `.option` declared ⇒ `[ "app" ]` |
| `alias` rewrites only the aliasing source's own keys — an inbound cross-origin reference to the old path is not rewritten, and the link fails when the manifest is forced | `lib/rewrite.nix:73-76` (`@ref` tokens skip `aliasKey`), `lib/link.nix:53-56` (`entryOf`'s named throw). Aliasing `a`'s `apps/media/pg` → `apps/media/postgres` while `wire."b/apps/app".dbreq = "a/apps/media/pg"`: `T (deepSeq .manifest true)` ⇒ `false`. Positive control without the alias ⇒ `true` |
| `checkCapability` with `requires = [ ]` passes against `provides = [ ]` | `lib/contract.nix:25-30`; ⇒ `T` `true`. Positive control `requires = [ "read" ]` against `provides = [ ]` ⇒ `false`. Test: `test-capability-unsatisfied-throws` (`ci/tests/contract.nix`) |
| Three underscore-prefixed names are part of the public surface, not internals | `lib/default.nix:47,55,65`; `_scaffold` ⇒ `true`, plus `_hasRefPrefix` and `_recordHas`. Test: `test-lib-evaluates` (`ci/tests/smoke.nix`) reads `_scaffold` |
| Seven names defined by the modules are **not** re-exported by `lib/default.nix` | `isNode`, `refPrefix` (`lib/normalize.nix:93,95`), `selfName` (`lib/ref.nix:30`), `facetKeys`, `isHoleValue` (`lib/facets.nix:35,37`), `toGraph`, `relabelFn` (`lib/rewrite.nix:97`); each `genLink ? <name>` ⇒ `false`. Positive control: `genLink ? link` ⇒ `true` |
| `includes` manifest rows always carry `via = null`; only `kind = "hole"` rows name a facet | `lib/link.nix:182-189`, `lib/manifest.nix:7-21`; `map (e: { inherit (e) kind via; }) (filter (e: e.kind == "includes") wired.manifest)` ⇒ `[ { kind = "includes"; via = null; } ]` |
| `README.md:234-235` documents `cd ci && just ci`, but no Justfile exists | `git ls-files \| grep -ci justfile` ⇒ `0`; `find . -iname justfile -o -iname '*.just'` ⇒ 0 hits. Positive control, same `find` predicate over gen-select and gen-scope: `gen-select/examples/css-selectors/Justfile` |

## Theory

Claimed in `README.md:242-258` as a single flat Feature → Paper table — this repo declares no Implements / Informed-by split — and restated in the module header comments.

- **Néron, Tolmach, Visser & Wachsmuth (2015), *A Theory of Name Resolution*** — a registry is a labeled graph, not a tree of values; resolution is name resolution; D\<I\<P visibility (`lib/normalize.nix:1-6`).
- **van Antwerpen, Poulsen, Rouvoet & Visser (2018), *Scopes as Types*** — end-of-path resolution over scopes.
- **Mokhov (2017), *Algebraic Graphs with Class*** — `overlay` as the union monoid (commutative, associative, idempotent) and the origin stamp as a coproduct injection (`lib/union.nix:1-5`, `lib/rewrite.nix:1-6`).
- **Kilpatrick, Dreyer, Peyton Jones & Marlow (2014), *Backpack*; Yang (2016), *Backpack to Work*** — hermetic linking with explicit signatures; a hole is a facet-require (`lib/wire.nix:1-5`).
- **MacQueen (1984); Leroy (1995), *Applicative Functors…*; Dreyer (2005)** — instantiation creates identity, **applicative** default, generative alternative rejected (`lib/identity.nix:5-6`).
- **Flatt & Felleisen (1998), *Units*** — first-class linkable units.
- **Jones, Gomard & Sestoft (1993), *Partial Evaluation…*** — binding-time analysis, per-node closed/open.
- **Palmer et al. (2024), *Intensional Functions*** — the inspectable wrapped-fn functor realizing open aspects.
- **Hedin (2000), *Reference Attributed Grammars*; Hedin & Magnusson (2003), *JastAdd*** — forward reference / reverse inter-type resolution (`lib/link.nix:148-151`).
- **Merkle (1987); Dolstra (2006), *The Purely Functional Software Deployment Model*** — content-addressed identity and the lock pattern (`lib/identity.nix:2-3`, `lib/manifest.nix:1-4`).
- **Bracha & Cook (1990), *Mixin-based Inheritance*** — the capability provide/require contract (`lib/contract.nix:2-3`).
- **Findler & Felleisen (2002); Rondon, Kawaguchi & Jhala (2008), *Liquid Types*** — the refined-value contract (`lib/contract.nix:3-4`).
- **Pierce (2002), *TAPL* §19.3** — nominal inhabitance (class IS-A).
- **Reynolds (1972), *Definitional Interpreters*** — hole-fillings defunctionalized to node ids before hashing (`lib/identity.nix:5-6`, `lib/wire.nix:2-3`).
- **Kahn (1974)** — dataflow-conduit homonym disambiguation (`pipe.channel`, not a keySemantics channel).

**Checked invariants.** `ci/tests/purity.nix` scans comment-stripped `lib/**.nix` plus the root `flake.nix` and `default.nix` for `nixpkgs`, `lib.`, `{ lib }`, `{ lib,`, `evalModules`, `mkOption`, asserting the library surface is nixpkgs-lib-free. `ci/tests/conductor-oracle.nix` runs gen-aspects, gen-scope, gen-resolve, gen-algebra, gen-schema and gen-edge in one chain, so a stubbed sibling breaks it.

## Drift check

```sh
nix eval --json .#lib --apply 'builtins.attrNames'
```

Current output (verbatim):

```json
["_hasRefPrefix","_recordHas","_scaffold","bindNode","checkCapability","checkRefined","contractOf","disjointUnion","entry","holesOf","instantiatedId","keyRefTargetId","link","nodeId","normalize","order","originLabel","originStamp","parseRef","providesOf","renderOrigin","requiresOf"]
```

**Checks.** Test-runner invocation (from the repo root; CI runs the same command with `working-directory: ci`, `.github/workflows/ci.yml:13,18`, followed by `nix fmt -- --ci` at `:19`):

```sh
nix flake check ./ci
```
