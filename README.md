# gen-link

[![CI](https://github.com/sini/gen-link/actions/workflows/ci.yml/badge.svg)](https://github.com/sini/gen-link/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/sini)

Cross-flake aspect federation over origin-labeled subgraphs, implemented as a pure Nix library.

gen-link lets a downstream flake reuse aspects and registry components published by an *external* flake — rescoping them, aliasing individual nodes, and wiring cross-origin references that are pinned and diffable the way `flake.lock` pins inputs. A flake exports a subgraph of aspects; another flake imports it, links it against its own graph, and materializes the result.

gen-link is a **Class-B conductor** in the gen-resolve sense: it owns only *sequencing* plus three genuinely-new coordinates — an **origin coordinate**, a **disjoint-union-with-relabel** over origin-labeled subgraphs, and a **resolution manifest** — and **delegates every computation** to an existing gen sibling. It never hashes an identity (gen-schema does), never resolves an edge (gen-resolve does), never checks a contract (gen-algebra / gen-schema do), never unions raw graphs (gen-scope does), never materializes (gen-edge does). It stores nothing between calls and carries no domain knowledge (NixOS, home-manager, den).

## Table of Contents

- [Overview](#overview)
- [Position in the Ecosystem](#position-in-the-ecosystem)
- [Gen Ecosystem](#gen-ecosystem)
- [Usage](#usage)
- [The `link` Conductor](#the-link-conductor)
- [Declaring Facet Ports](#declaring-facet-ports)
- [Public API](#public-api)
- [Testing](#testing)
- [Theoretical Foundations](#theoretical-foundations)

## Overview

A collection of aspects is a **labeled graph, not a tree of values** (Néron 2015): nodes (aspects), `includes` edges (references to nodes that already exist), a vocabulary (its `keySemantics`), and its declared holes (facet-requires — the open ports an importer fills). "Reuse a component" means "union a subgraph and resolve references across the seam," never "copy a value."

`link` federates a list of sources in six steps (§[The `link` Conductor](#the-link-conductor)). Two edge kinds, and only two — Backpack's import/signature duality (Kilpatrick 2014):

- **`includes` are concrete** — the target node exists. Authored by-value (`includes = [ config.aspects.base ]`) or by-key (`aspects.keyRef "y/apps/pg"`); at the graph level the distinction disappears — both become edges between node ids, relabeled identically by the origin-rewrite.
- **holes are parametric** — a facet-require to a not-yet-present node, filled by `wire` at instantiation, and the only edge that folds into instantiation identity.

**Origin makes the union disjoint by construction.** Two flakes that each define `apps/media/pg` become distinct nodes because origin is a datum in the one content-address formula (§[Public API](#public-api) — Identity). **Instantiation creates identity** applicatively (Leroy 1995): `y/foo` wired to `self/pg` is a different node from `y/foo` wired to `y/pg`.

## Position in the Ecosystem

```
gen-prelude / gen-merge         (pure base — builtins + byte-mode module merge)
gen-algebra  — record algebra: has / assertSatisfies         (capability check)
gen-schema   — hashIdentity, checkRefinements, refined       (identity + contracts)
gen-aspects  — keySemantics grammar, aspect identity          (aspect payload)
gen-scope    — algebraic-graph union/query (Mokhov 2017)      (graph primitives)
gen-graph    — reachability / condensation                    (visibility)
gen-resolve  — reference + resolve/materialize                (edge resolution)
gen-edge     — (S,T,P,M) materialize                          (terminal move)

gen-link (Class B) — federation conductor
  depends on: gen-scope, gen-resolve, gen-schema, gen-algebra, gen-aspects (+ gen-prelude)
  owns:       origin coordinate · disjoint-union+relabel · resolution manifest
  stores:     nothing (accessor pattern)
  knows:      nothing about NixOS / den / aspect semantics
```

Consumers (den-hoag, and any downstream flake) wire gen-link the way den wires gen-resolve: they supply the domain vocabulary; gen-link supplies the federation sequencing.

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-prelude](https://github.com/sini/gen-prelude) | Pure nixpkgs-lib-free utility base (builtins re-exports + vendored lib utils) |
| [gen-algebra](https://github.com/sini/gen-algebra) | Pure primitives (record algebra, search monad, either, intensional identity) |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries + `hashIdentity` / `checkRefinements` / `refined` |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect type system (`keySemantics` grammar, `aspectId`, `keyRef`) |
| [gen-scope](https://github.com/sini/gen-scope) | HOAG scope-graph evaluator + algebraic graphs (`overlay` / `gmap`) |
| [gen-graph](https://github.com/sini/gen-graph) | Accessor-based graph query combinators (reachability, condensation) |
| [gen-resolve](https://github.com/sini/gen-resolve) | Demand-driven RAG evaluator (`reference` — forward/reverse edge resolution) |
| [gen-edge](https://github.com/sini/gen-edge) | (S,T,P,M) materialize — the terminal move into a class evaluation |
| [gen-link](https://github.com/sini/gen-link) | **This lib** — cross-flake aspect federation conductor |

## Usage

gen-link is **Class B**: nixpkgs-lib-free, depending only on gen-prelude and five sibling `.lib` values, each self-wiring its own deps. The `lib/**` surface is pure list/attr combinators + builtins — no module system, no `nixpkgs.lib` (enforced by `ci/tests/purity.nix`). The flake exposes a single `.lib` value output.

```nix
# flake.nix
{
  inputs.gen-link.url = "github:sini/gen-link";
  outputs = { gen-link, ... }:
    let link = gen-link.lib;
    in { /* ... */ };
}

# Or without flakes (siblings auto-derived from the pinned flake.lock):
let link = import ./gen-link { };
in { /* ... */ }
```

## The `link` Conductor

The single entry point is a pure `link` call. It stores nothing.

```nix
link {
  # sources: the origin-labeled subgraphs to federate. The importing flake joins as a source too, so
  #   `self/*` references resolve — `self` is the surface name for its origin []. Per-source `origin`
  #   (rescope) and `alias` (per-node rename) live on each entry; `keySemantics` is the source's facet
  #   vocabulary.
  sources = [
    { registry = self.aspects; origin = [ ]; keySemantics = ks; }               # importer; `self` origin = []
    { registry = a.aspects;    origin = [ "a" ]; keySemantics = ks; }           # default origin = source identity
    { registry = b.aspects;    origin = [ "b" ]; keySemantics = ks;
      alias = { "apps/media/pg" = "apps/media/postgres"; }; }                    # per-node rename
  ];

  # wire: fill federation HOLES (facet-requires) only. Each filler is a node REFERENCE — a structured
  #   `{ origin; path }` or an origin-qualified path-string — bound by id, never a raw closure
  #   (defunctionalization, Reynolds 1972). `includes` are NEVER wired; the pipeline (not `wire`) fills
  #   context args (host/user/…).
  wire."b/apps/app".dbreq = "a/apps/media/pg";   # fill b/apps/app's `dbreq` facet-require with a's pg node
}
→ {
  graph    = <origin-disjoint merged gen-scope subgraph>;   # not stored by gen-link
  manifest = <ordered list of { kind; from; to; via }>;     # diffable: cross-origin edges bound
  nodes    = { <id> = { origin; node }; };                  # the id → source-node index
  bound    = [ { id; node; origin; holeFillings } ];        # instantiated hole-filled nodes (folded ids)
  resolved = { <requirerId> = <resolved provider tags | null>; };   # per-requirer cross-origin resolution
}
```

**The six-step sequencing** (the only thing gen-link owns; every computation is delegated):

1. **Normalize + origin-rewrite each source.** Ingest the registry into a source-relative graph (nodes keyed by `.key`; `includes` — by-value or by-key — extracted uniformly into id-edges), then rename every node to its federation **identifier** under the assigned origin and swap every edge endpoint — a uniform relabel over gen-scope `gmap`, no content re-evaluation. Per-node `alias` renames apply here.
2. **Disjoint union.** `overlay` the origin-rewritten subgraphs (gen-scope). Origin makes the union collision-free by construction.
3. **Mint, in staged passes.** Each `wire` entry contributes a RELATUM to its requirer — label the facet name, value the filler's identifier — and every merged node is emitted to gen-scope's `mintStrata` at a pass derived from the wire graph. A relatum resolves only against what strictly earlier passes settled, so an ill-founded filling (a node filling its own hole, or a cycle) cannot resolve and is refused by name. An unwired required facet is a separate, loud, named error.
4. **Resolve cross-origin references.** Run gen-resolve `reference` (forward `includes` nearest-binding) over the merged graph *as the scope*. Resolution is active-edge-driven and lazy — gen-link does not scan.
5. **Type-check each active cross-origin edge.** Capability → gen-algebra `record` (`requires ⊆ provides`); refined → gen-schema `checkRefinements`. A type failure is a loud, named error at the edge.
6. **Record the manifest.** Every cross-origin `includes` edge and every wired hole is written to the manifest with both endpoints' ids — the `flake.lock` pattern (Dolstra 2006) applied to cross-origin edges.

Steps 1–2 are the "disjoint-union + relabel" owned row; step 6 is the "resolution manifest" owned row; steps 3–5 delegate. gen-link mints nothing itself: what it owns of step 3 is the pass derivation and the emitter list. gen-link holds no graph between calls — the merged `graph` is a gen-scope value returned to the caller.

## Declaring Facet Ports

A **facet is the sole typed port of federation** — the only place a federated edge acquires a type. Classes (payload) are moved to materialization unresolved; channels are inert data. A facet key is declared in a source's `keySemantics` with `category = "facet"` and a `contract` flavor (`"capability"` — default — or `"refined"`).

**A facet keySemantics entry MUST carry a real `.option`.** Without it, gen-aspects builds no facet option and the key falls through the freeform fallback into a *nested aspect* — which breaks the port model and pollutes the graph with spurious origin-stamped vertices. With the option declared, `node.<F>` is a genuine option value carrying the per-node contract.

```nix
# a facet option: a raw slot carrying { provides ? []; requires ? []; } (capability), read per-node.
facetOpt = merge.mkOption { type = merge.types.raw; default = null; };

keySemantics = {
  nixos = { category = "class"; };                                    # payload — materialized, never typed
  dbcap = { category = "facet"; contract = "capability"; option = facetOpt; };
  dbreq = { category = "facet"; contract = "capability"; option = facetOpt; };
};
```

A node then expresses its role through that option's value:

```nix
config.aspects = {
  provider.dbcap = { provides = [ "read" "write" ]; };   # a capability PROVIDER
  requirer.dbreq = { requires = [ "read" ]; };           # a REQUIRER (an unfilled hole until wired)
};
```

**Capability** (default): `provides` / `requires` are role-tag lists. gen-link turns the provider's `provides` into a record and checks `requires ⊆ provides` via gen-algebra `record.has`, raising its **own named edge error** if a tag is missing (`record.assertSatisfies` is the secondary arbiter on success). Bracha & Cook (1990).

**Refined value** (`contract = "refined"`): the keySemantics entry carries a `refinedType` — a real gen-schema refined type built with `genSchema.refined <base> <refinements>`, **not** a raw refinements list. gen-schema `checkRefinements` reads `type.__schema.refinements`, so a bare list carries no `__schema` and the check would silently no-op. Findler & Felleisen (2002); Rondon et al. (2008).

```nix
portFacet = { category = "facet"; contract = "refined";
  refinedType = genSchema.refined genMerge.types.int [ { name = "positive"; check = v: v > 0; } ];
  option = facetOpt; };
```

Facets **type** an already-established edge; they never **resolve** one (resolution is the scope-graph query). Conflating the two would put a global constraint solve on the eval path.

## Public API

The flake's `.lib` exposes:

### `link { sources, wire ? {} } → { graph; manifest; nodes; bound; resolved }`

The federation conductor (above). `sources` entries are `{ registry; origin ? []; alias ? {}; keySemantics ? {}; }`; `wire` is `{ "<requirerRef>" = { <facet> = "<fillerRef>"; }; }`. References are origin-qualified path-strings or structured `{ origin; path }`.

### Identifier and identity

ADR-0016 ruling 5 keeps two things apart, and this library used to merge them.

An **identifier** is the name a node carries as a vertex: the origin-qualified reference,
`"<origin>/<key>"`, with `[]` rendered `"self"`. It keys the node map, it is what an edge endpoint
names, and it is what a `wire` entry writes. It is a string a reader can write by hand.

★ **The federated reference grammar is ruled kind-qualified** — `namespace.<kind-segment>.name`,
one grammar with the local `den.aspects.name`, so that a cross-kind name collision is inexpressible
by construction rather than policed by a uniqueness check. That grammar is **not built here**: this
migration ships the two-segment form above. It is recorded so the current form is not mistaken for
the settled law.

An **identity** is the derived content-address, minted once per node by gen-schema's `hashIdentity`
and reached ONLY through gen-scope's minting entry. It rides as a FIELD on the node —
`(link {…}).nodes."<identifier>".identity` — never as its name.

**gen-link publishes no function that computes either one.** There is nothing to construct for an
identifier, and a second route to an identity would be a second minting authority. The four
functions that used to live here — `nodeId`, `keyRefTargetId`, `instantiatedId`, `bindNode` — are
retired: all four minted whatever input they were handed with no membership test, so keeping them
would have left the ill-founded instantiation expressible on the surface while it was inexpressible
through `link`.

**The manifest carries identifiers and kinds, never identities.** Ruling 5 rules the content-address
internal addressing only — consistent within an evaluation, with nothing durable depending on it
across them — and the manifest is designed for a consumer to serialize to a `gen-link.lock`. The
rows are therefore the readable coordinates, which is also the more useful artefact: an identity is
a computed value a human cannot read back, while the coordinates are the function's own INPUTS, so
a tool can reproduce or query the output from the rows and the identity rebuilds from them.

Each endpoint carries its node's **kind** alongside its identifier, under `fromKind` / `toKind` —
names deliberately distinct from the row's own `kind`, which means the row's sort (`"includes"` or
`"hole"`) and is a property of the relation rather than of either endpoint. One string per endpoint
is what keeps the rebuild total once a federation mixes kinds: an identity is `"<kind>:" + digest`,
so the kind is only the tag prefix, and once the identity stops being serialized no other field
carries it. Without it a consumer holding a row could not name the kind to mint with.

### References & Origin

| Function | Signature | Semantics |
|----------|-----------|-----------|
| `parseRef` | `ref → { __keyRef; origin; path; key }` | Parse a structured or string reference; `self` maps to origin `[]`. Slash-splitting delegates to gen-aspects `keyRef`. |
| `originLabel` | `origin → string` | The raw `"/"`-joined origin list; `[]` → `""`. `renderOrigin` is what builds identifiers. |
| `renderOrigin` | `origin → string` | Surface rendering for manifests/errors/keys: `[]` → `"self"`. |

### Federation Steps

| Function | Signature | Semantics |
|----------|-----------|-----------|
| `normalize` | `registry → { nodesByKey; edges; refByToken }` | Registry → source-relative, origin-free includes-graph. No content re-evaluation (bounded WHNF head-touch only). |
| `originStamp` | `{ normalized; origin; alias ? {} } → { graph; idToNode }` | The origin-rewrite: uniform relabel over gen-scope `gmap` (by-value and by-key edges alike) + per-node `alias`. |
| `disjointUnion` | `[ { graph; idToNode } ] → { graph; idToNode }` | `overlay` the origin-stamped subgraphs (gen-scope union monoid). Collision-free by construction. |

### Facets & Contracts

| Function | Signature | Semantics |
|----------|-----------|-----------|
| `holesOf` | `ks → node → [facet]` | The node's facet keys whose value carries `requires` (unfilled capability holes). |
| `providesOf` | `ks → node → [tag]` | Union of `provides` tags across the node's facet keys. |
| `requiresOf` | `node → facet → [tag]` | A capability hole's `requires` demand. |
| `contractOf` | `ks → facet → "capability" \| "refined"` | The facet's contract flavor (default `"capability"`). |
| `checkCapability` | `{ edgeName; provides; requires } → record \| throw` | `requires ⊆ provides` via gen-algebra `record.has`; own named error on a missing tag, `record.assertSatisfies` on success. |
| `checkRefined` | `{ edgeName; refinedType; value } → value \| throw` | gen-schema `checkRefinements` over a `__schema`-tagged refined type; own named error on a violation. |

### Manifest

| Function | Signature | Semantics |
|----------|-----------|-----------|
| `entry` | `{ kind; from; fromKind; to; toKind; via ? null } → manifestEntry` | Construct one manifest entry. `kind` is the ROW's sort (`∈ { "includes", "hole" }`); `fromKind`/`toKind` are the endpoint NODES' kinds. Every field but `via` is required. |
| `order` | `[ entry ] → [ entry ]` | Deterministic ordering for diff stability. |

## Testing

The sufficiency claim — **gen-link sequences the real siblings and adds only origin + union + manifest** — is proven by the conductor oracle (`ci/tests/conductor-oracle.nix`), one chain end-to-end:

1. Origin-union two toy collections that each define `apps/media/pg` → assert their federated nodes have **distinct** origin-qualified identifiers.
2. Wire a capability edge and type-check it via gen-algebra; the unsatisfiable variant throws named.
3. Resolve the cross-origin include via gen-resolve `reference` → the requirer sees the provider's tags (a stubbed `reference` returns null and the assertion catches it — gen-resolve is genuinely load-bearing).
4. Rebuild the wired node's identity from its identifier and its relatum's identity through gen-schema directly, and assert the minting run produced the same digest.
5. Materialize the linked node's class content through gen-edge.

If any sibling were stubbed, the chain breaks.

```bash
nix flake check ./ci                       # build + run the full suite
cd ci && just ci                           # run all tests
cd ci && just ci conductor-oracle          # run one suite
```

**52 tests across 13 suites**: `conductor-oracle`, `link`, `identity`, `rewrite`, `facets`, `normalize`, `contract`, `ref`, `wire`, `union`, `demo`, `smoke`, and `purity`. The `purity` suite asserts the `lib/**` surface never touches `nixpkgs.lib`, enforcing the Class B invariant.

## Theoretical Foundations

| Feature | Paper |
|---------|-------|
| Registry as scope graph; resolution as name resolution; D\<I\<P visibility | Néron, Tolmach, Visser & Wachsmuth (2015) "A Theory of Name Resolution" |
| End-of-path resolution over scopes | van Antwerpen, Poulsen, Rouvoet & Visser (2018) "Scopes as Types" |
| Disjoint union of subgraphs; overlay as the union monoid | Mokhov (2017) "Algebraic Graphs with Class" |
| Hermetic linking with explicit signatures (holes) | Kilpatrick, Dreyer, Peyton Jones & Marlow (2014) "Backpack: Retrofitting Haskell with Interfaces"; Yang (2016) "Backpack to Work" |
| Instantiation creates identity; **applicative** default (Leroy), generative alternative rejected (Dreyer) | MacQueen (1984) "Modules for Standard ML"; Leroy (1995) "Applicative Functors…"; Dreyer (2005) "Understanding and Evolving the ML Module System" |
| First-class linkable units | Flatt & Felleisen (1998) "Units: Cool Modules for HOT Languages" |
| Binding-time analysis (per-node closed/open) | Jones, Gomard & Sestoft (1993) "Partial Evaluation and Automatic Program Generation" |
| The inspectable wrapped-fn functor realizing open aspects | Palmer et al. (2024) "Intensional Functions" |
| Forward reference / reverse inter-type resolution | Hedin (2000) "Reference Attributed Grammars"; Hedin & Magnusson (2003) "JastAdd" |
| Content-addressed identity; the lock pattern | Merkle (1987) hash trees; Dolstra (2006) "The Purely Functional Software Deployment Model" |
| Capability contract (provide/require) | Bracha & Cook (1990) "Mixin-based Inheritance" |
| Refined-value contract | Findler & Felleisen (2002) "Contracts for Higher-Order Functions"; Rondon, Kawaguchi & Jhala (2008) "Liquid Types" |
| Nominal inhabitance (class IS-A) | Pierce (2002) "Types and Programming Languages" §19.3 |
| Defunctionalize hole-fillings to data before hashing | Reynolds (1972) "Definitional Interpreters for Higher-Order Programming Languages" |
| Dataflow-conduit homonym disambiguation (`pipe.channel`, NOT keySemantics channel) | Kahn (1974) "The Semantics of a Simple Language for Parallel Programming" |

See the full design in [`papers/den-architecture/gen-specs/gen-link/2026-07-24-gen-link-design.md`](https://github.com/sini/den) and the canonical [`REFERENCE.md`](https://github.com/sini/den).
