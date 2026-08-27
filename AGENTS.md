# gen-link — agent capability sheet

## Scope

Cross-flake aspect federation: `link { sources, wire }` normalizes each source aspect registry into an origin-free includes-graph, stamps every node with a federation origin, disjoint-unions the subgraphs, mints every merged node's identity through `gen-scope`'s staged minting entry with each facet filling as a relatum, and returns a diffable resolution manifest — owning only the origin coordinate, the union-with-relabel, and the manifest, and delegating every computation to a gen sibling.

A node is NAMED by its **identifier**, the origin-qualified reference (`"b/apps/app"`); its **identity** is the derived content-address and rides as a FIELD on the node. gen-link mints nothing itself and publishes no identity-computing function.

★ **The federated reference grammar is RULED KIND-QUALIFIED** — `namespace.<kind-segment>.name`, one grammar with the local `den.aspects.name`, under which a cross-kind name collision is inexpressible by construction rather than policed. **This migration does not build it**: what ships here is the two-segment origin-qualified form above. The grammar is the future surface's law, recorded so a reader does not take today's form as the settled one.

## Not this library's job

Quoted text is the owner's own `flake.nix` `description` field, verbatim.

| Responsibility | Owner |
|---|---|
| Refined types, `checkRefinements` | `gen-schema` — "gen-schema: typed record registry with extension points for the pure-gen module system". gen-link never calls `hashIdentity` **or** `sha256`: `git grep -c hashIdentity -- lib` ⇒ no match, and the authority reaches the minting run through `gen-scope`'s own assembly. `ci/tests/authority.nix` asserts the refusals that authority owes |
| Minting an identity, the staged pass, the frozen set, the unresolved-relatum refusal | `gen-scope` — via `mintStrata`. gen-link supplies emitters and reads back `{ nodes; edges; strata; unrun }`; it re-exports no `gen-scope` name and publishes no view of the frozen set |
| Aspect payload, the `keySemantics` grammar, the aspect-chain `key`, `keyRef` slash-splitting | `gen-aspects` — "gen-aspects: aspect-oriented composition types (pure-gen, re-hosted on gen-merge)". `parseRef` owns only the `self` ⟷ `[]` surface mapping (`lib/ref.nix:5-6`), and the identifier is built from `aspects.key` — `aspectId` is no longer called at all |
| Algebraic-graph `overlay` / `gmap` / `vertices` / `edges`, and the scope evaluator (`buildNodes`, `eval`) | `gen-scope` — "gen-scope: demand-driven attribute grammar evaluator over algebraic scope graphs" |
| Resolving an edge (forward `includes` nearest-binding) | `gen-view` — `referenceResolution`, a defining query whose compute is TOTAL DELEGATION to an injected query authority, and the authority `lib/link.nix` injects is this repository's own `scope`. The term is Néron et al. 2015's rule (X). ★ **This replaced `gen-resolve`, which left the repository in the same change**: its `reference` was the entire dependence — one call site — and the three discipline flags it left to the delegate's silent defaults are now written down at the declaration |
| Materialization — moving class content into a class evaluation | `gen-view` — "gen-view: the substrate's derived-view constructor — the (L, E, \<, k) carrier with van Antwerpen's relation sort published as a raw calculus, and the named compositions over it". A channel is a named materialized query result, so the terminal move is a `viewRelation` over an authored scope graph and the cell it lands in is a `placement` fact rather than a declaration field. ★ **`gen-view` IS NOW A ROOT INPUT** — it was previously ci-only, reaching this repository as the `genView` specialArg alone, because `lib/**` read nothing from it. `lib/link.nix` now reads `view.referenceResolution`, so the root flake declares it and `default.nix` self-constructs it (no threading: the construct takes its query authority as an injected field, so there is no second evaluator to collapse). The `gen-edge` (S,T,P,M) edge algebra was the surface this replaced at that call site; **that retirement has now landed** — ADR-0010 §3, off the `gen/lib/mkGenLibs.nix` roster and no longer a `gen` hub input, with the repository orphaned as reference under ADR-0031 §3's F3 pattern. gen-view is the ecosystem's materialization owner outright, and this repository migrated off gen-edge before the retirement rather than at it |
| Record algebra, capability satisfaction (`record.has` / `record.assertSatisfies`) | `gen-algebra` — "gen-algebra: pure Nix algebra — search monad, records, intensional functions, either" |
| General utilities (gen-link is nixpkgs-lib-free; `flake.nix:4-6`) | `gen-prelude` — "gen-prelude: vendored, nixpkgs-lib-free pure utilities for the gen ecosystem" |
| Module merge, `evalModuleTree`, `mkOption` — building the aspect registry gen-link ingests | `gen-merge` — "gen-merge — pure-Nix byte-mode module MERGE engine (evalModuleTree) for the pure-gen module system". Not a gen-link input; it is a `ci/flake.nix:5` input only |
| Reachability, condensation, visibility queries over the merged graph | `gen-graph` — "gen-graph: accessor-based graph query combinators". Named in `README.md:42,64`; not a gen-link input (`flake.nix:19-35`) |
| Dataflow channels — the `pipe.channel` homonym, distinct from a keySemantics channel (`README.md:258`) | **`gen-view`, which inherited it — `gen-pipe` RETIRED as a library rather than moving as one.** ADR-0010 §3, the same ruling that retired gen-edge: twelve of gen-pipe's seventeen exports name gen-view constructs and `sel` retires into `gen-select`. Off the `gen/lib/mkGenLibs.nix` roster and not a `gen` hub input; the repository orphans as reference under ADR-0031 §3's F3 pattern. The homonym warning survives the retirement and is why this row is kept — a keySemantics channel here is still not a dataflow channel, and the name that used to collide now belongs to gen-view |
| Any domain vocabulary (NixOS / home-manager / den keys) | the consuming flake — every facet and class key arrives as a per-source `keySemantics` parameter (`lib/link.nix:44-51`; `README.md:9`) |
| Serializing the manifest to disk (a `gen-link.lock`) | the consuming flake — `lib/manifest.nix:3-4` states gen-link writes nothing |

## Consumer surface

Sweep of all 126 `flake.nix` files under `/home/sini/Documents/repos` (depth 6) for `gen-link.url`: two declarations.

| Consumer | Evidence |
|---|---|
| `gen` (the ecosystem hub) | `gen/flake.nix:35` declares the input; `gen/lib/mkGenLibs.nix:34` re-exports it as `link` |
| `gen-link/examples/demo` | `examples/demo/flake.nix:8` |

`den-hoag` does **not** declare gen-link, re-measured at its current HEAD with `git grep -cI -E '<tok>' HEAD -- '*.nix'`: `gen-link\.url` ⇒ **0**, against firing controls `gen-scope\.url` ⇒ 1 and `gen-schema\.url` ⇒ 1 and a negative control `zzqqNoSuch\.url` ⇒ 0. gen-link reaches `den-hoag/ci/flake.lock` only transitively, through the hub. The one predicate that hits — `instantiatedId|keyRefTargetId|disjointUnion|originStamp` ⇒ **2** — is a substring collision on den-hoag's own local `originStampModule`. ★ One den-hoag COMMENT (`ci/tests/namespace-origin-identity.nix:3`) names gen-link's `nodeId` as the formula reference while reaching the content-address through gen-aspects `aspectId` directly; that function is now retired, so the reference is stale on this side — the behaviour it describes is unaffected, because it never called gen-link. No den-hoag `.nix` file calls a gen-link export.

## Exports

Entry: `inputs.gen-link.lib` (flake), or `gen.lib.link` through the hub. Root `default.nix` is a **function** — `import ./gen-link { }` — whose named parameters (`prelude`, `scope`, `resolve`, `schema`, `algebra`, `aspects`) default to the `flake.lock` pins and may each be overridden.

**References & origin** — `lib/ref.nix`

| Export | Signature |
|---|---|
| `parseRef` | `ref -> { __keyRef; origin; path; key }` (string sugar or structured `{ origin; path }`; `self` ⇒ origin `[]`) |
| `originLabel` | `origin -> string` — the RAW `"/"`-joined list; `[]` ⇒ `""`, which is where it differs from `renderOrigin` |
| `renderOrigin` | `origin -> string` — surface rendering; `[]` ⇒ `"self"` |

★ **There is no identity module and no identity export.** `nodeId`, `keyRefTargetId`, `instantiatedId` and `bindNode` are RETIRED, and `lib/identity.nix` and `lib/wire.nix` are deleted: under one minting authority a per-node minting function on this surface is a second route to the same thing, and all four minted arbitrary input with no membership test. An identifier needs no constructor — a consumer writes `"${renderOrigin origin}/${key}"`, which is the dividend of the name no longer being a digest.

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

**Manifest, conductor** — `lib/manifest.nix`, `lib/link.nix`

| Export | Signature |
|---|---|
| `entry` | `{ kind, from, fromKind, to, toKind, via ? null } -> manifestEntry`. `kind` is the ROW's sort (∈ `{ "includes", "hole" }`); `fromKind`/`toKind` are the ENDPOINT NODES' kinds, a different vocabulary on a different substrate. All but `via` are REQUIRED — a defaulted endpoint kind would answer for a node whose kind nobody supplied |
| `order` | `[ entry ] -> [ entry ]` (deterministic sort for diff stability) |
| `link` | `{ sources, wire ? {} } -> { graph; manifest; nodes; bound; resolved }` |
| `_scaffold` | `true` (a constant) |

**`link` argument and return shape** (consumed/produced, not exports). Each `sources` entry is `{ registry; keySemantics; origin ? []; alias ? {}; }` — `keySemantics` carries **no default** and an entry omitting it is refused by name (a source with no facets writes `keySemantics = { }`). `wire` is `{ "<requirerRef>" = { <facet> = "<fillerRef>"; }; }`. The return record carries `graph` (the merged gen-scope graph, vertices = identifiers), `manifest` (ordered `{ kind; from; fromKind; to; toKind; via }` — endpoints are **identifiers plus their node kinds**, never identities), `nodes` (`{ <identifier> = { origin; node; identity }; }`), `bound` (`[ { identifier; identity; node; origin; relata } ]`), and `resolved` (`{ <requirerIdentifier> = [tag] | null; }`).

## Entry points by task

| Task | Reach for |
|---|---|
| Federate several registries end to end | `link { sources = […]; wire = {…}; }` |
| Fill a facet-require across the seam | a `wire."<origin>/<key>".<facet> = "<origin>/<key>"` entry |
| Ingest one registry into a graph without federating | `normalize <registry>` |
| Rescope one registry under an origin (or rename its nodes) | `originStamp { normalized; origin; alias; }` |
| Merge already-stamped subgraphs | `disjointUnion [ … ]` |
| Name a node, or the target of an `@ref` include | write the identifier: `"${renderOrigin origin}/${key}"` — the same string a `wire` key takes |
| Read a node's identity | `(link {…}).nodes."<identifier>".identity` — minted by the one authority, never recomputed here |
| Read what a wiring folded into a node's identity | `(link {…}).bound` — each record carries `identifier`, `identity` and its `relata` |
| Read a node's ports | `holesOf` / `providesOf` / `requiresOf` / `contractOf` |
| Type-check one edge by hand | `checkCapability` (tag subset) / `checkRefined` (gen-schema refined type) |
| Turn an origin into a manifest/error string | `renderOrigin` (`[]` ⇒ `"self"`); `originLabel` for the hash preimage |
| Build or sort manifest rows outside `link` | `entry` / `order` |
| Explore the whole surface in a REPL | `nix repl ./ci/repl.nix` — `import ./.. { }` plus nixpkgs `lib` |

## Measured traps

★ **COVERAGE, STATED HONESTLY.** The three ★ CLOSED rows below were re-measured at the revision this file ships with, through the suite cells each one names, and each carries BOTH readings — the landed one and the same cell against the predecessor `lib/link.nix`. Every OTHER row carries its measurement from the earlier whole-table run at `4635cad` and was **not** re-run here.

The fixture, common to both runs, is built from `ci/flake.lock` with **one** `gen-schema` instance threaded through `gen-aspects` and `gen-scope` (mirroring the flake `follows` — letting either self-construct its own puts two content-address formulas in one evaluation, and the declared holes then read as unwired). `ks` declares `nixos` as `category = "class"` and `dbcap`/`dbreq` as `category = "facet"`, `contract = "capability"`, each with a declared `merge.types.raw` option; `regA` holds `apps/media/pg` providing `[ "read" "write" ]`; `regB` holds the same path `apps/media/pg` plus `apps/app` requiring `[ "read" ]` and including `keyRef "a/apps/media/pg"`; `srcs` places them at origins `[ "a" ]` / `[ "b" ]`; `wired = link { sources = srcs; wire."b/apps/app".dbreq = "a/apps/media/pg"; }`; `unwired = link { sources = srcs; }`; `T = e: (builtins.tryEval e).success`.

| Trap | Evidence |
|---|---|
| ★ **CLOSED — the completeness guard fires on EVERY field.** It used to be forced under `.manifest` alone, so `.graph`, `.bound`, `.resolved` and `.nodes` all evaluated clean with a hole left open, and a consumer reading the merged graph got a silent pass | `lib/link.nix` returns through `prelude.mapAttrs (_field: builtins.deepSeq unwiredHoleGuard)`, which makes the reach total by construction rather than by an enumeration a later field falls out of. On `unwired`, `map (f: T (deepSeq unwired.${f} true)) [ "graph" "bound" "resolved" "nodes" ]` ⇒ `[ false false false false ]`; the same cell run against the PREDECESSOR `lib/link.nix` reads `[ true true true true ]`. Positive control, same four fields on the wired variant ⇒ `[ true true true true ]`. ★ The MINT's refusal keeps its narrower reach (`.manifest` and every `identity` field, the row further down) — forcing every node's content-address is what a caller reading only `graph` is asking not to pay, while this guard is a walk over the merged nodes' facet values. Tests: `test-the-completeness-guard-fires-on-every-field` + `test-control-every-field-evaluates-on-a-closed-federation` (`ci/tests/link.nix`) |
| ★ **CLOSED — a source that omits `keySemantics` is REFUSED BY NAME.** It used to silently disable the hole guard for **its own** nodes: `holesOf { }` answers `[ ]` on a node that declares a hole, so the federation linked with the hole open and said nothing | `lib/link.nix` (`ksByOrigin`'s entry throws naming the origin; `ksOf`'s `{ }` fallback went with it — that second one is unreachable from the surface, since no merged node carries an origin no source stamped, and it is there because a silent `{ }` is the very fallback being removed). With regB's entry lacking `keySemantics`, `T (deepSeq .manifest true)` ⇒ `false`, the message naming origin `b`; the same cells against the predecessor library ⇒ the link SUCCEEDS (nix-unit reports the message cell ☢️ *Expected error, but no error was caught*). Positive control on the same predicate, same run: `holesOf ks app` ⇒ `[ "dbreq" ]` (`facets.test-holes-of-requirer`). ★ A source with genuinely no facets writes `keySemantics = { }` — the decision is the author's, not a default's. Tests: `link.test-a-source-without-keysemantics-refuses`, `link-refusals.test-a-source-without-keysemantics-names-the-origin-and-the-repair` |
| ★ **DISSOLVED, recorded because it shipped as a trap for a while.** `resolved` used to be keyed by the holeless `nodeId` while the bound record carried the instantiation id, so `wired.resolved ? (head wired.bound).id` ⇒ `false` and a consumer joining the two silently got nothing | Both are now the node's identifier: `wired.resolved ? "b/apps/app"` ⇒ `true`, `(head wired.bound).identifier` ⇒ `"b/apps/app"`, and the two agree ⇒ `true`. That is the conflation ADR-0016 ruling 5 forbids, removed rather than documented. Test: `test-resolution-through-reference-resolution` (`ci/tests/link.nix`) |
| A node with no `includes` gets **no** `resolved` entry — absent, not `null` | keys come from `importIndex`, i.e. edge sources only; `wired.resolved ? "a/apps/media/pg"` ⇒ `false` while `wired.nodes ? "a/apps/media/pg"` ⇒ `true` |
| ★ **CLOSED — a `wire` key that names no DECLARED hole on the requirer is refused by name.** It used to be ACCEPTED, become a relatum, and fork the requirer's identity on a name no source declares | `lib/link.nix`'s `wireOf` checks every filling against `facets.holesOf rKs rEntry.node` before the contract dispatch — the `holesOf` check at the wire site the predecessor row prescribed. It has to be there rather than in the contract: `lib/facets.nix:10` still answers `"capability"` for any key at all, `:18` still returns `[ ]` for an undeclared one, and `lib/contract.nix:27-30` still passes `requires = [ ]` against any `provides`, so the type-check is VACUOUSLY satisfied by an undeclared name. Adding `notAFacet = "a/apps/media/pg"` beside a real `dbreq` filling: `T (deepSeq .manifest true)` ⇒ `false`, the message naming the entry and listing `declared: dbreq`; against the predecessor library the same fixture links green (the predecessor row recorded the consequences: hole rows `[ "dbreq" "notAFacet" ]` and a forked identity). Positive control, the same wire minus that one key: `(head wired.bound).relata` ⇒ `{ dbreq = "a/apps/media/pg"; }`. ★★ THE GUARD IS NOW SYMMETRIC — the wire site demands wired ⊆ holes and the completeness guard demands holes ⊆ wired, so a node's `wire` entries ARE its declared holes. ★ A REFINED facet is reached through the same door: its hole is declared the way a capability hole is (`<facet> = { requires = …; }`, which is what `holesOf` reads), and `contract = "refined"` then types the FILLER's value on top. No fixture in this repository wires a refined facet end to end. Tests: `link.test-a-filling-naming-no-declared-hole-refuses` + `link.test-control-a-declared-hole-filling-still-binds`, `link-refusals.test-a-filling-naming-no-declared-hole-names-the-entry-and-the-declared-holes` |
| `contractOf` answers for keys that are not facets at all, and never throws | `lib/facets.nix:10`; `contractOf ks "neverDeclared"` ⇒ `"capability"`, and `contractOf ks "nixos"` (a `category = "class"` key) ⇒ `"capability"`. ★ The wire site no longer REACHES it with such a key — the `holesOf` check above runs first — so this is now a property of the function read directly, not a live route into a vacuous contract |
| The IDENTIFIER ignores the node's `.key` — overriding it is dead; `name` is the live field | `lib/ref.nix` builds it from `aspects.key` = `pathKey ((meta.aspect-chain or []) ++ [ name ])`, which is the same reading a keyRef's path gets. Overriding `.key` in place: `"a/apps/media/pg"` still a vertex ⇒ `true`. Positive control, overriding `name` instead ⇒ `false`. Tests: `test-overriding-the-key-attribute-does-not-rename-the-vertex` and its control (`ci/tests/identifier.nix`) |
| Two sources given the **same** `origin` collapse same-key nodes silently — `idToNode` is folded with `//`, last source wins | `lib/union.nix:12`; stamping regA and regB both at origin `[ "a" ]`, nodes whose `.key` is `apps/media/pg` ⇒ `1`. Positive control at origins `[ "a" ]` / `[ "b" ]` ⇒ `2`. Test (distinct-origin direction only): `test-same-path-distinct-ids` (`ci/tests/union.nix`) |
| `originLabel []` and `renderOrigin []` disagree by design: `""` vs `"self"` | Observed `""` / `"self"`. ★ `renderOrigin` is the live one — it builds every identifier, manifest row, refusal and `ksByOrigin` key. `originLabel` used to supply the hash preimage's origin datum and now has **no call site in `lib/`**, so it survives as a coordinate accessor rather than as part of any formula. Test: `test-origin-label-and-render` (`ci/tests/ref.nix`) |
| `parseRef "self"` (bare, no slash) yields an **empty** key, not an error; and `self` is special only in first position | `lib/ref.nix:12-17`; `"self"` ⇒ `{ origin = [ ]; key = ""; }`, `"y/self/pg"` ⇒ `{ origin = [ "y" ]; key = "self/pg"; }`. Positive control: `"y/apps/pg"` ⇒ `{ origin = [ "y" ]; key = "apps/pg"; }` |
| An **anonymous inline** `includes` entry becomes a dangling edge that crashes the origin-rewrite with an error `tryEval` cannot catch | gen-aspects coerces `includes = [ { notAKey = 1; } ]` into a full aspect node keyed `main/includes/0`, but `lib/normalize.nix:26-31` strips `includes` before the child scan — so `nodesByKey` ⇒ `[ "main" ]` while `edges` ⇒ `[ { from = "main"; to = "main/includes/0"; } ]`. Forcing `originStamp` on it: `error: attribute '"main/includes/0"' missing` at `lib/rewrite.nix:33:30`, and the surrounding `T (…)` never returns. Positive control: the same expression over a by-value `includes` registry ⇒ `true` |
| Declaring a facet key **without** an `.option` keeps the hole visible but adds a phantom graph node | `lib/normalize.nix:21,26-31`; `README.md:134`. With `dbreq` declared `category = "facet"` and no `option`: `holesOf ksNoOpt app` ⇒ `[ "dbreq" ]` (the freeform fallback still carries `requires`), yet `attrNames (normalize reg).nodesByKey` ⇒ `[ "app" "app/dbreq" ]`. Positive control with `.option` declared ⇒ `[ "app" ]` |
| `alias` rewrites only the aliasing source's own keys — an inbound cross-origin reference to the old path is not rewritten, and the link fails when the manifest is forced | `lib/rewrite.nix:73-76` (`@ref` tokens skip `aliasKey`), `lib/link.nix:53-56` (`entryOf`'s named throw). Aliasing `a`'s `apps/media/pg` → `apps/media/postgres` while `wire."b/apps/app".dbreq = "a/apps/media/pg"`: `T (deepSeq .manifest true)` ⇒ `false`. Positive control without the alias ⇒ `true` |
| `checkCapability` with `requires = [ ]` passes against `provides = [ ]` | `lib/contract.nix:25-30`; ⇒ `T` `true`. Positive control `requires = [ "read" ]` against `provides = [ ]` ⇒ `false`. Test: `test-capability-unsatisfied-throws` (`ci/tests/contract.nix`) |
| Three underscore-prefixed names are part of the public surface, not internals | `_scaffold` ⇒ `true`, plus `_hasRefPrefix` and `_recordHas`. Test: `test-lib-evaluates` (`ci/tests/smoke.nix`) reads `_scaffold` |
| Seven names defined by the modules are **not** re-exported by `lib/default.nix` | `isNode`, `refPrefix` (`lib/normalize.nix:93,95`), `selfName` (`lib/ref.nix:30`), `facetKeys`, `isHoleValue` (`lib/facets.nix:35,37`), `toGraph`, `relabelFn` (`lib/rewrite.nix:97`); each `genLink ? <name>` ⇒ `false`. Positive control: `genLink ? link` ⇒ `true` |
| ★★ **A REFUSAL IS A PROPERTY OF THE CALL ONLY FOR A CONSUMER THAT REACHES THE MINT.** On an ill-founded federation (a filling cycle), `attrNames result.nodes` ⇒ `true` and `deepSeq result.graph` ⇒ `true` — the vertex names and the merged graph evaluate cleanly and report nothing. Reading ANY node's `identity` ⇒ `false`, and `.manifest` ⇒ `false` | The identifiers are computed from the sources, so they are available before minting begins; the mint is forced by `.manifest` and by every `identity` field. Positive controls on the well-founded fixture: both ⇒ `true`. ⇒ a consumer that only enumerates vertex names sees a clean federation, and one that reads a manifest or an identity gets the named refusal |
| `includes` manifest rows always carry `via = null`; only `kind = "hole"` rows name a facet | `map (e: { inherit (e) kind via; }) (filter (e: e.kind == "includes") wired.manifest)` ⇒ `[ { kind = "includes"; via = null; } ]`. ★ Both row sorts DO carry `fromKind` and `toKind` — those are the endpoints' node kinds and are unconditional; `via` is the relation's label and only a hole has one |
| `README.md:234-235` documents `cd ci && just ci`, but no Justfile exists | `git ls-files \| grep -ci justfile` ⇒ `0`; `find . -iname justfile -o -iname '*.just'` ⇒ 0 hits. Positive control, same `find` predicate over gen-select and gen-scope: `gen-select/examples/css-selectors/Justfile` |

## Theory

Claimed in `README.md:242-258` as a single flat Feature → Paper table — this repo declares no Implements / Informed-by split — and restated in the module header comments.

- **Néron, Tolmach, Visser & Wachsmuth (2015), *A Theory of Name Resolution*** — a registry is a labeled graph, not a tree of values; resolution is name resolution; D\<I\<P visibility (`lib/normalize.nix:1-6`).
- **van Antwerpen, Poulsen, Rouvoet & Visser (2018), *Scopes as Types*** — end-of-path resolution over scopes.
- **Mokhov (2017), *Algebraic Graphs with Class*** — `overlay` as the union monoid (commutative, associative, idempotent) and the origin stamp as a coproduct injection (`lib/union.nix:1-5`, `lib/rewrite.nix:1-6`).
- **Kilpatrick, Dreyer, Peyton Jones & Marlow (2014), *Backpack*; Yang (2016), *Backpack to Work*** — hermetic linking with explicit signatures; a hole is a facet-require, filled by a `wire` entry (`lib/link.nix`, step 3a).
- **MacQueen (1984); Leroy (1995), *Applicative Functors…*; Dreyer (2005)** — instantiation creates identity, **applicative** default, generative alternative rejected: same fillings ⇒ same identity, because a filling is a relatum and the identity is a total function of the kind, the identifier and the resolved relata (`lib/link.nix`, step 3c).
- **Flatt & Felleisen (1998), *Units*** — first-class linkable units.
- **Jones, Gomard & Sestoft (1993), *Partial Evaluation…*** — binding-time analysis, per-node closed/open.
- **Palmer et al. (2024), *Intensional Functions*** — the inspectable wrapped-fn functor realizing open aspects.
- **Hedin (2000), *Reference Attributed Grammars*; Hedin & Magnusson (2003), *JastAdd*** — forward reference / reverse inter-type resolution (`lib/link.nix:148-151`).
- **Merkle (1987); Dolstra (2006), *The Purely Functional Software Deployment Model*** — content-addressed identity and the lock pattern (`lib/manifest.nix:1-4`). The identity is `gen-schema`'s; what this library owns is the manifest, and it records **identifiers** so that nothing durable rests on internal addressing.
- **Bracha & Cook (1990), *Mixin-based Inheritance*** — the capability provide/require contract (`lib/contract.nix:2-3`).
- **Findler & Felleisen (2002); Rondon, Kawaguchi & Jhala (2008), *Liquid Types*** — the refined-value contract (`lib/contract.nix:3-4`).
- **Pierce (2002), *TAPL* §19.3** — nominal inhabitance (class IS-A).
- **Apt, Blair & Walker (1988), *Towards a Theory of Declarative Knowledge*** — a minting pass is a STRATUM: each is closed before the next begins, which is what makes a cycle among minted nodes unwritable rather than detected (`lib/link.nix`, step 3b; the construction itself is `gen-scope`'s).
- **Reynolds (1972), *Definitional Interpreters*** — a filling is defunctionalized to a REFERENCE, never a closure; the reference is now the relatum's identifier rather than a hash of it (`lib/link.nix`, step 3a).
- **Kahn (1974)** — dataflow-conduit homonym disambiguation (`pipe.channel`, not a keySemantics channel).

**Checked invariants.** `ci/tests/purity.nix` scans comment-stripped `lib/**.nix` plus the root `flake.nix` and `default.nix` for `nixpkgs`, `lib.`, `{ lib }`, `{ lib,`, `evalModules`, `mkOption`, asserting the library surface is nixpkgs-lib-free. `ci/tests/conductor-oracle.nix` runs gen-aspects, gen-scope (including `mintStrata`), gen-algebra, gen-schema and gen-view (`referenceResolution`) in one chain, so a stubbed sibling breaks it; its identity cell REBUILDS the digest from the identifier and the relatum's identity through the authority rather than comparing the library to itself. `ci/tests/lock-shape.nix` asserts that each lock resolves to exactly ONE `gen-schema` node, counted through `.root` input resolution and armed so a counter blind to a second instance fails.

## Drift check

```sh
nix eval --json .#lib --apply 'builtins.attrNames'
```

Current output (verbatim):

```json
["_hasRefPrefix","_recordHas","_scaffold","checkCapability","checkRefined","contractOf","disjointUnion","entry","holesOf","link","normalize","order","originLabel","originStamp","parseRef","providesOf","renderOrigin","requiresOf"]
```

**Checks.** Test-runner invocation (from the repo root; CI runs the same command with `working-directory: ci`, `.github/workflows/ci.yml:13,18`, followed by `nix fmt -- --ci` at `:19`):

```sh
nix flake check ./ci
```
