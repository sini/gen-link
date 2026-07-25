# gen-link demo

Federates two aspect collections (`a`, `b`) that both define `apps/media/pg`, then wires
collection B's `apps/app` facet-require (`dbreq`) to collection A's postgres capability provider.

```
nix eval ./#report                # human summary
nix eval ./#manifest --json       # the diffable resolution manifest
```

`b/apps/app` links to `a/apps/media/pg` across the origin seam; the manifest pins that edge.
